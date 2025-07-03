// k8s-cr-watcher.js

const k8s = require('@kubernetes/client-node');
const yaml = require('js-yaml');
const diff = require('deep-diff').diff;

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function sanitizeObject(obj) {
  const sanitized = JSON.parse(JSON.stringify(obj));
  if (sanitized.metadata) {
    delete sanitized.metadata.managedFields;
    delete sanitized.metadata.generation;
    delete sanitized.metadata.resourceVersion;
    delete sanitized.metadata.creationTimestamp;
  }
  return sanitized;
}

function getValueAtPath(obj, pathArray) {
  return pathArray.reduce((acc, key) => (acc && acc[key] !== undefined) ? acc[key] : undefined, obj);
}

// Helper function to format differences into a human-readable string
function formatDifferences(differences, previousObj, currentObj) {
  let output = '';
  const handledArrayPaths = new Set();

  differences.forEach(d => {
    const path = d.path.join('.');
    if (d.kind === 'A') {
      const arrayPath = d.path.join('.');
      if (!handledArrayPaths.has(arrayPath)) {
        const beforeArray = getValueAtPath(previousObj, d.path);
        const afterArray = getValueAtPath(currentObj, d.path);

        output += `• ${arrayPath}:\n\nBefore:\n${yaml.dump(beforeArray).trim().split('\n').join('\n')}\nAfter:\n${yaml.dump(afterArray).trim().split('\n').join('\n')}\n`;
        handledArrayPaths.add(arrayPath);
      }
    } else {
      // Check if this change is part of an already handled array
      const isPartOfHandledArray = Array.from(handledArrayPaths).some(arrayPath => path.startsWith(arrayPath));
      
      if (!isPartOfHandledArray) {
        switch (d.kind) {
          case 'E': // Edit
            output += `• ${path}: '${JSON.stringify(d.lhs)}' => '${JSON.stringify(d.rhs)}'\n`;
            break;
          case 'N': // New
            output += `• ${path}: Added '${JSON.stringify(d.rhs)}'\n`;
            break;
          case 'D': // Deleted
            output += `• ${path}: Removed '${JSON.stringify(d.lhs)}'\n`;
            break;
          default:
            output += `• ${path}: Changed\n`;
        }
      }
    }
  });

  return output;
}

// Function to extract change information from an event
function extractChangeInfo(type, apiObj, previousObj, currentObj) {
  const name = apiObj.metadata.name;
  const namespace = apiObj.metadata.namespace;
  const kind = apiObj.kind;
  const apiVersion = apiObj.apiVersion;

  let changeInfo = `${type}: ${kind} "${name}"`;
  if (namespace) {
    changeInfo += ` in namespace "${namespace}"`;
  }
  changeInfo += ` (apiVersion: ${apiVersion})`;

  if (type === 'MODIFIED' && previousObj) {
    const differences = diff(previousObj, apiObj);
    if (differences && differences.length > 0) {
      // Filter out non-essential diffs
      const essentialDifferences = differences.filter(d => {
        const path = d.path.join('.');
        return !path.startsWith('metadata.generation') &&
               !path.startsWith('metadata.resourceVersion') &&
               !path.startsWith('metadata.creationTimestamp') &&
               !path.startsWith('metadata.managedFields') &&
               !path.startsWith('status');
      });

      if (essentialDifferences.length > 0) {
        changeInfo += '\n\nDifferences:\n' + formatDifferences(essentialDifferences, previousObj, apiObj);
      } else {
        changeInfo += '\n\nNo meaningful differences detected';
      }
    } else {
      changeInfo += '\n\nNo differences detected';
    }
  }

  return changeInfo;
}

async function watchCRs(contextName, delaySeconds, durationSeconds) {
  let changeCount = 0;
  let isWatchSetupComplete = false;

  console.log(`Waiting for ${delaySeconds} seconds before starting the test...`);
  await delay(delaySeconds * 1000);
  console.log('Delay complete. Starting the test.');

  const kc = new k8s.KubeConfig();
  kc.loadFromDefault();

  const contexts = kc.getContexts();
  const context = contexts.find(c => c.name === contextName);

  kc.setCurrentContext(contextName);

  const k8sApi = kc.makeApiClient(k8s.CustomObjectsApi);
  const apisApi = kc.makeApiClient(k8s.ApisApi);

  async function getResources(group, version) {
    try {
      const { body } = await k8sApi.listClusterCustomObject(group, version, '');
      return body.resources || [];
    } catch (error) {
      console.error(`Error getting resources for ${group}/${version}: ${error}`);
      return [];
    }
  }

  // Function to watch a specific CR
  async function watchCR(group, version, plural, abortController) {
    const watch = new k8s.Watch(kc);
    let resourceVersion;

    try {
      // Get the latest resourceVersion
      const listResponse = await k8sApi.listClusterCustomObject(group, version, plural);
      resourceVersion = listResponse.body.metadata.resourceVersion;

      // Cache of previous objects (sanitized)
      const objectCache = {};

      // Initialize the object cache
      if (listResponse.body.items) {
        listResponse.body.items.forEach(item => {
          objectCache[item.metadata.uid] = item;
        });
      }

      await watch.watch(
        `/apis/${group}/${version}/${plural}`,
        {
          abortSignal: abortController.signal,
          allowWatchBookmarks: true,
          resourceVersion: resourceVersion
        },
        (type, apiObj) => {
          if (isWatchSetupComplete) {
            const uid = apiObj.metadata.uid;

            // Sanitize the current object by removing non-essential metadata
            const sanitizedObj = sanitizeObject(apiObj);

            let previousObj = objectCache[uid];

            if (previousObj) {
              // Clone previousObj to avoid mutation
              previousObj = JSON.parse(JSON.stringify(previousObj));
            }

            if (type === 'ADDED' || type === 'MODIFIED' || type === 'DELETED') {
              const changeInfo = extractChangeInfo(type, sanitizedObj, previousObj, sanitizedObj);

              // Only log meaningful changes
              if (type === 'MODIFIED' && changeInfo.includes('No meaningful differences detected')) {
                // Skip logging if there are no meaningful changes
                return;
              }

              console.log(changeInfo);
              console.log('---');
              console.log(yaml.dump(sanitizedObj).trim()); // Display the full object in YAML
              console.log('---');

              if (type === 'DELETED') {
                delete objectCache[uid];
              } else {
                objectCache[uid] = sanitizedObj;
              }

              changeCount++;
            }
          }
        },
        (err) => {
          if (err && err.message !== 'aborted') {
            console.error(`Error watching ${group}/${version}/${plural}: ${err}`);
          }
        }
      );
    } catch (error) {
      if (error.message !== 'aborted') {
        console.error(`Error setting up watch for ${group}/${version}/${plural}: ${error}`);
      }
    }
  }

  console.log(`Using context: ${contextName}`);
  console.log(`Watching for CR changes with apiVersion containing "istio", "gloo", "solo" or "gateway.networking.k8s.io" for ${durationSeconds} seconds...`);

  const abortController = new AbortController();
  const watchPromises = [];

  const { body: apiGroups } = await apisApi.getAPIVersions();

  for (const group of apiGroups.groups) {
    if (group.name.includes('istio') || group.name.includes('gloo') || group.name.includes('solo') || group.name.includes('gateway.networking.k8s.io')) {
      const latestVersion = group.preferredVersion || group.versions[0];
      const resources = await getResources(group.name, latestVersion.version);

      for (const resource of resources) {
        if (resource.kind && resource.name && !resource.name.includes('/')) {
          watchPromises.push(watchCR(group.name, latestVersion.version, resource.name, abortController));
        }
      }
    }
  }

  console.log("Watch setup complete. Listening for changes...");
  console.log('---');
  
  isWatchSetupComplete = true;

  await new Promise(resolve => setTimeout(resolve, durationSeconds * 1000));

  abortController.abort();
  console.log(`Watch completed after ${durationSeconds} seconds.`);
  console.log(`Total changes detected: ${changeCount}`);

  await Promise.allSettled(watchPromises);

  return changeCount;
}

module.exports = { watchCRs };
