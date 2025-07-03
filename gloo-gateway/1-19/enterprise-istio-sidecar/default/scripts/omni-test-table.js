const fs = require('fs');

/**
 * Parse test log file and generate a markdown table
 * @param {string} logFilePath - Path to the log file
 */
function generateTableFromLog(logFilePath) {
  // Read the log file
  const logContent = fs.readFileSync(logFilePath, 'utf8');

  // Find all scenario markers with their original IDs
  const scenarioMarkers = [];
  const scenarioRegex = /Scenario (\d+[a-z]?): ([^\n]+)/g;
  let scenarioMatch;

  while ((scenarioMatch = scenarioRegex.exec(logContent)) !== null) {
    scenarioMarkers.push({
      id: scenarioMatch[1],
      name: scenarioMatch[2].trim(),
      position: scenarioMatch.index
    });
  }

  // Process each scenario
  const scenarios = [];
  for (let i = 0; i < scenarioMarkers.length; i++) {
    const currentMarker = scenarioMarkers[i];
    const nextMarker = scenarioMarkers[i + 1];

    // Extract content from current marker to next marker (or end of file)
    const startPos = currentMarker.position;
    const endPos = nextMarker ? nextMarker.position : logContent.length;
    const content = logContent.substring(startPos, endPos);

    // Extract waypoint information from scenario name and content
    const waypointInfo = extractWaypointInfoFromScenario(currentMarker.name, content);

    scenarios.push({
      id: currentMarker.id,
      name: currentMarker.name,
      fullName: `Scenario ${currentMarker.id}: ${currentMarker.name}`,
      content: content,
      waypointInfo: waypointInfo
    });
  }

  // Table headers
  let markdownTable = '# Multi-Cluster Communication Test Matrix\n\n';
  markdownTable += '| Scenario | Origin | Destination | Local Waypoint | Remote Waypoint | Failover | AuthorizationPolicy | Results |\n';
  markdownTable += '|----------|--------|-------------|----------------|-----------------|----------|---------------------|---------|';

  // Process each scenario
  scenarios.forEach(scenario => {
    // Extract test results for this scenario
    const directTests = extractDirectTests(scenario.content);
    const waypointTests = extractWaypointTests(scenario.content);
    const ingressTests = extractIngressTests(scenario.content);

    // Process direct tests
    markdownTable += processTestGroup(scenario.fullName, directTests, "direct", scenario.waypointInfo);

    // Process local waypoint tests
    const localWaypointTests = waypointTests.filter(t => t.waypointType === 'local');
    markdownTable += processTestGroup(scenario.fullName, localWaypointTests, "localWaypoint", scenario.waypointInfo);

    // Process remote waypoint tests
    const remoteWaypointTests = waypointTests.filter(t => t.waypointType === 'remote');
    markdownTable += processTestGroup(scenario.fullName, remoteWaypointTests, "remoteWaypoint", scenario.waypointInfo);

    // Process ingress tests
    markdownTable += processIngressTests(scenario.fullName, ingressTests, scenario.waypointInfo);
  });

  return markdownTable;
}

/**
 * Extract waypoint information from scenario name and content
 * @param {string} scenarioName - The name of the scenario
 * @param {string} content - The content of the scenario
 * @returns {Object} Waypoint information
 */
function extractWaypointInfoFromScenario(scenarioName, content) {
  const waypointInfo = {
    localWaypoint: '-',
    remoteWaypoint: '-',
    failover: '-',
    authPolicy: '-'
  };

  // Check scenario name for waypoint information
  const scenarioLower = scenarioName.toLowerCase();
  
  // Check for local waypoint in scenario name
  if (scenarioLower.includes('local istio waypoint')) {
    waypointInfo.localWaypoint = 'Istio';
  } else if (scenarioLower.includes('local gloo waypoint')) {
    waypointInfo.localWaypoint = 'Gloo';
  }
  
  // Check for remote waypoint in scenario name
  if (scenarioLower.includes('remote istio waypoint')) {
    waypointInfo.remoteWaypoint = 'Istio';
  } else if (scenarioLower.includes('remote gloo waypoint')) {
    waypointInfo.remoteWaypoint = 'Gloo';
  }
  
  // Check for failover in scenario name
  if (scenarioLower.includes('failover')) {
    waypointInfo.failover = 'Yes';
  }
  
  // Check for authorization policy in scenario name
  if (scenarioLower.includes('authorization') || scenarioLower.includes('auth policy')) {
    waypointInfo.authPolicy = 'Yes';
  }
  
  // Look for more explicit waypoint information in the test description
  const waypointDescRegex = /Local Waypoint=([^,]+), Remote Waypoint=([^,]+), Failover=([^,]+), Authorization Policy=([^,\)]+)/;
  const descMatch = content.match(waypointDescRegex);
  
  if (descMatch) {
    if (descMatch[1] && descMatch[1] !== 'None') {
      waypointInfo.localWaypoint = descMatch[1];
    }
    if (descMatch[2] && descMatch[2] !== 'None') {
      waypointInfo.remoteWaypoint = descMatch[2];
    }
    if (descMatch[3] && descMatch[3].toLowerCase() === 'true') {
      waypointInfo.failover = 'Yes';
    }
    if (descMatch[4] && descMatch[4].toLowerCase() === 'true') {
      waypointInfo.authPolicy = 'Yes';
    }
  }
  
  return waypointInfo;
}

/**
 * Process a group of tests and consolidate if all are successful
 * @returns {string} Markdown table rows
 */
function processTestGroup(scenarioName, tests, testType, scenarioWaypointInfo) {
  let tableRows = '';
  if (tests.length === 0) return tableRows;

  // Group tests by origin
  const testsByOrigin = {};
  tests.forEach(test => {
    if (!testsByOrigin[test.origin]) {
      testsByOrigin[test.origin] = [];
    }
    testsByOrigin[test.origin].push(test);
  });

  // Process each origin group
  Object.keys(testsByOrigin).forEach(origin => {
    const testsForOrigin = testsByOrigin[origin];
    const allSuccessful = testsForOrigin.every(test => test.result === '✅ Success');

    if (allSuccessful && testsForOrigin.length > 1) {
      // Consolidate if all tests are successful
      // Determine waypoint values based on test type and scenario defaults
      let localWaypoint = scenarioWaypointInfo.localWaypoint;
      let remoteWaypoint = scenarioWaypointInfo.remoteWaypoint;

      // If the test explicitly specifies a waypoint, use that instead
      if (testType === "localWaypoint" && testsForOrigin[0].waypoint) {
        localWaypoint = testsForOrigin[0].waypoint;
      } else if (testType === "remoteWaypoint" && testsForOrigin[0].waypoint) {
        remoteWaypoint = testsForOrigin[0].waypoint;
      } else if (testType === "direct") {
        // For direct tests, we use the scenario defaults unless explicitly overridden
        if (testsForOrigin[0].localWaypoint) {
          localWaypoint = testsForOrigin[0].localWaypoint;
        }
        if (testsForOrigin[0].remoteWaypoint) {
          remoteWaypoint = testsForOrigin[0].remoteWaypoint;
        }
      }

      // Add consolidated row
      tableRows += `\n| ${scenarioName} | ${origin} | All destinations | ${localWaypoint} | ${remoteWaypoint} | ${scenarioWaypointInfo.failover} | ${scenarioWaypointInfo.authPolicy} | ✅ Success |`;
    } else {
      // Add individual rows if not all are successful or only one test
      testsForOrigin.forEach(test => {
        let localWaypoint = scenarioWaypointInfo.localWaypoint;
        let remoteWaypoint = scenarioWaypointInfo.remoteWaypoint;

        // Override with test-specific waypoint if available
        if (testType === "localWaypoint" && test.waypoint) {
          localWaypoint = test.waypoint;
        } else if (testType === "remoteWaypoint" && test.waypoint) {
          remoteWaypoint = test.waypoint;
        } else if (testType === "direct") {
          if (test.localWaypoint) {
            localWaypoint = test.localWaypoint;
          }
          if (test.remoteWaypoint) {
            remoteWaypoint = test.remoteWaypoint;
          }
        }

        tableRows += `\n| ${scenarioName} | ${test.origin} | ${test.destination} | ${localWaypoint} | ${remoteWaypoint} | ${scenarioWaypointInfo.failover} | ${scenarioWaypointInfo.authPolicy} | ${test.result} |`;
      });
    }
  });

  return tableRows;
}

/**
 * Process ingress tests with special handling
 * @returns {string} Markdown table rows
 */
function processIngressTests(scenarioName, ingressTests, scenarioWaypointInfo) {
  let tableRows = '';
  if (ingressTests.length === 0) return tableRows;

  // Group by ingress type and waypoint type
  const groupedTests = {};

  ingressTests.forEach(test => {
    const key = `${test.ingressType}-${test.waypointType}-${test.waypoint || 'none'}`;
    if (!groupedTests[key]) {
      groupedTests[key] = [];
    }
    groupedTests[key].push(test);
  });

  // Process each group
  Object.keys(groupedTests).forEach(key => {
    const testsInGroup = groupedTests[key];
    const allSuccessful = testsInGroup.every(test => test.result === '✅ Success');
    const waypointType = testsInGroup[0].waypointType;
    const waypoint = testsInGroup[0].waypoint || '';

    let localWaypoint = scenarioWaypointInfo.localWaypoint;
    let remoteWaypoint = scenarioWaypointInfo.remoteWaypoint;

    // Override with test-specific waypoint if available
    if (waypointType === 'local' && waypoint) {
      localWaypoint = waypoint;
    } else if (waypointType === 'remote' && waypoint) {
      remoteWaypoint = waypoint;
    }

    if (allSuccessful && testsInGroup.length > 1) {
      // Add consolidated row
      tableRows += `\n| ${scenarioName} | ${testsInGroup[0].ingressType} | All destinations | ${localWaypoint} | ${remoteWaypoint} | ${scenarioWaypointInfo.failover} | ${scenarioWaypointInfo.authPolicy} | ✅ Success |`;
    } else {
      // Add individual rows
      testsInGroup.forEach(test => {
        tableRows += `\n| ${scenarioName} | ${test.ingressType} | ${test.destination} | ${localWaypoint} | ${remoteWaypoint} | ${scenarioWaypointInfo.failover} | ${scenarioWaypointInfo.authPolicy} | ${test.result} |`;
      });
    }
  });

  return tableRows;
}

/**
 * Extract direct tests (no waypoint specified)
 */
function extractDirectTests(section) {
  const tests = [];
  const testRegex = /client-in-(mesh|ambient) => ([^(]+)[^\n]+\((\d+)ms\)/g;
  const failRegex = /client-in-(mesh|ambient) => ([^:]+):/g;

  // Match successful tests
  let match;
  while ((match = testRegex.exec(section)) !== null) {
    const origin = match[1] === 'mesh' ? 'client (sidecar)' : 'client (ambient)';
    const destination = formatDestination(sanitizeString(match[2].trim()));

    // Skip tests that include waypoints
    if (match[0].includes('WAYPOINT =>')) continue;

    tests.push({
      origin,
      destination,
      result: '✅ Success'
    });
  }

  // Match failed tests
  while ((match = failRegex.exec(section)) !== null) {
    // Skip tests that include waypoints
    if (match[0].includes('WAYPOINT =>')) continue;

    // Check if this test is already recorded as successful
    const origin = match[1] === 'mesh' ? 'client (sidecar)' : 'client (ambient)';
    const destination = formatDestination(sanitizeString(match[2].trim()));

    // Only add if not already in the tests array
    if (!tests.some(t => t.origin === origin && t.destination === destination)) {
      const errorMsg = extractErrorMessage(section, match.index);
      tests.push({
        origin,
        destination,
        result: `❌ ${errorMsg}`
      });
    }
  }

  return tests;
}

/**
 * Extract tests with waypoints
 */
function extractWaypointTests(section) {
  const tests = [];
  const waypointRegex = /client-in-(mesh|ambient) => (LOCAL|REMOTE)_(ISTIO|GLOO)_WAYPOINT => ([^(]+)[^\n]+\((\d+)ms\)/g;
  const waypointFailRegex = /client-in-(mesh|ambient) => (LOCAL|REMOTE)_(ISTIO|GLOO)_WAYPOINT => ([^:]+):/g;

  // Match successful tests
  let match;
  while ((match = waypointRegex.exec(section)) !== null) {
    const origin = match[1] === 'mesh' ? 'client (sidecar)' : 'client (ambient)';
    const waypointType = match[2].toLowerCase();
    const waypointProvider = match[3] === 'ISTIO' ? 'Istio' : 'Gloo';
    const destination = formatDestination(sanitizeString(match[4].trim()));

    tests.push({
      origin,
      destination,
      waypointType,
      waypoint: waypointProvider,
      result: '✅ Success'
    });
  }

  // Match failed tests
  while ((match = waypointFailRegex.exec(section)) !== null) {
    const origin = match[1] === 'mesh' ? 'client (sidecar)' : 'client (ambient)';
    const waypointType = match[2].toLowerCase();
    const waypointProvider = match[3] === 'ISTIO' ? 'Istio' : 'Gloo';
    const destination = formatDestination(sanitizeString(match[4].trim()));

    // Only add if not already in the tests array
    if (!tests.some(t =>
      t.origin === origin &&
      t.destination === destination &&
      t.waypointType === waypointType &&
      t.waypoint === waypointProvider
    )) {
      const errorMsg = extractErrorMessage(section, match.index);
      tests.push({
        origin,
        destination,
        waypointType,
        waypoint: waypointProvider,
        result: `❌ ${errorMsg}`
      });
    }
  }

  return tests;
}

/**
 * Extract ingress tests
 */
function extractIngressTests(section) {
  const tests = [];

  // Check for regular ingress tests
  if (section.includes('Tests all possible communication from istio ingress')) {
    const istioTests = extractIngressTestsByType(section, 'Istio Ingress');
    tests.push(...istioTests);
  }

  if (section.includes('Tests all possible communication from gloo ingress')) {
    const glooTests = extractIngressTestsByType(section, 'Gloo Ingress');
    tests.push(...glooTests);
  }

  // Check for waypoint ingress tests
  if (section.includes('Tests all possible communication from istio ingress through waypoint')) {
    const istioWaypointTests = extractIngressWaypointTests(section, 'Istio Ingress');
    tests.push(...istioWaypointTests);
  }

  if (section.includes('Tests all possible communication from gloo ingress through waypoint')) {
    const glooWaypointTests = extractIngressWaypointTests(section, 'Gloo Ingress');
    tests.push(...glooWaypointTests);
  }

  // Check for failures in ingress waypoint tests
  const ingressWaypointFailures = extractIngressWaypointFailures(section);
  tests.push(...ingressWaypointFailures);

  // Check for auth tests with ingress
  if (section.includes('AuthorizationPolicy is working properly')) {
    const authTests = extractAuthIngressTests(section);
    tests.push(...authTests);
  }

  // Deduplicate tests
  const uniqueTests = [];
  const uniqueKeys = new Set();
  
  for (const test of tests) {
    const key = `${test.ingressType}-${test.destination}-${test.waypointType || 'none'}-${test.waypoint || 'none'}-${test.result}`;
    if (!uniqueKeys.has(key)) {
      uniqueKeys.add(key);
      uniqueTests.push(test);
    }
  }

  return uniqueTests;
}

/**
 * Extract regular ingress tests
 */
function extractIngressTestsByType(section, ingressType) {
  const tests = [];
  const availableRegex = /\/(\w+(-\w+)?) is available/g;

  let match;
  let foundTests = false;

  while ((match = availableRegex.exec(section)) !== null) {
    foundTests = true;
    tests.push({
      ingressType,
      destination: sanitizeString(match[1]),
      waypointType: 'none',
      result: '✅ Success'
    });
  }

  // If no specific tests found but section exists, add a general entry
  if (!foundTests && section.includes(`Tests all possible communication from ${ingressType.toLowerCase().split(' ')[0]} ingress`)) {
    tests.push({
      ingressType,
      destination: 'All destinations',
      waypointType: 'none',
      result: '✅ Success'
    });
  }

  return tests;
}

/**
 * Extract ingress tests with waypoints
 */
function extractIngressWaypointTests(section, ingressType) {
  const tests = [];
  const regex = /\/(\w+(-\w+)?) is going through (LOCAL|REMOTE)_(ISTIO|GLOO)_WAYPOINT/g;

  let match;
  while ((match = regex.exec(section)) !== null) {
    const destination = sanitizeString(match[1]);
    const waypointType = match[3].toLowerCase();
    const waypointProvider = match[4] === 'ISTIO' ? 'Istio' : 'Gloo';

    tests.push({
      ingressType,
      destination,
      waypointType,
      waypoint: waypointProvider,
      result: '✅ Success'
    });
  }

  return tests;
}

/**
 * Extract auth tests for ingress
 */
function extractAuthIngressTests(section) {
  const tests = [];
  const authRegexFail = /(Istio|Gloo) ingress isn't allowed to send POST requests to \/([^\n]+)/g;
  const authRegexPass = /(Istio|Gloo) ingress is allowed to send GET requests to \/([^\n]+)/g;

  let match;
  // Extract failed auth tests
  while ((match = authRegexFail.exec(section)) !== null) {
    const ingressType = `${match[1]} Ingress`;
    const destination = sanitizeString(match[2].trim());

    // Check if this is actually a passing test (no 403)
    const isReallyFailing = !section.substring(match.index, match.index + 500)
      .includes(`expected '200' to include '403'`) &&
      !section.substring(match.index, match.index + 500)
        .includes(`expected Response`);

    tests.push({
      ingressType,
      destination,
      waypointType: 'none',
      result: isReallyFailing ? '✅ Success' : '❌ Auth fails'
    });
  }

  // Extract successful auth tests
  while ((match = authRegexPass.exec(section)) !== null) {
    const ingressType = `${match[1]} Ingress`;
    const destination = sanitizeString(match[2].trim());

    // Only add if not already in the auth tests array
    if (!tests.some(t => t.ingressType === ingressType && t.destination === destination)) {
      tests.push({
        ingressType,
        destination,
        waypointType: 'none',
        result: '✅ Success'
      });
    }
  }

  return tests;
}

/**
 * Sanitize a string by removing special characters like quotes
 * @param {string} str - The string to sanitize
 * @returns {string} - The sanitized string
 */
function sanitizeString(str) {
  if (!str) return '';
  // Remove quotes, backslashes, and other special characters
  return str.replace(/['"\\<>]/g, '');
}

/**
 * Format destination string for readability
 */
function formatDestination(dest) {
  // First sanitize the destination
  dest = sanitizeString(dest);
  
  if (dest.includes('in-mesh.httpbin')) {
    return dest.includes('svc.cluster.local') ? 'istio sidecar (local)' : 'remote-istio sidecar';
  } else if (dest.includes('in-ambient.httpbin')) {
    return dest.includes('svc.cluster.local') ? 'in-ambient (local)' : 'remote-in-ambient';
  }
  return dest;
}

/**
 * Extract error message from a test failure
 */
function extractErrorMessage(section, position) {
  const nextLines = section.substring(position, position + 500);

  // Check for waypoint routing issues - the most common error type
  if (nextLines.includes('to include \'waypoint-')) {
    const waypointMatch = nextLines.match(/to include '(waypoint-[^']+)'/);
    const waypointId = waypointMatch ? waypointMatch[1] : 'waypoint';
    return `Missing waypoint (${waypointId})`;
  }
  
  // Check for specific missing waypoints in ingress tests
  if (nextLines.includes('AssertionError') && 
      (nextLines.includes('Ingress => LOCAL_ISTIO_WAYPOINT') || 
       nextLines.includes('Ingress => REMOTE_ISTIO_WAYPOINT') ||
       nextLines.includes('Ingress => LOCAL_GLOO_WAYPOINT') ||
       nextLines.includes('Ingress => REMOTE_GLOO_WAYPOINT'))) {
    
    // Try to extract the specific waypoint ID from the error message
    const waypointMatch = nextLines.match(/to include '(waypoint-[^']+)'/);
    if (waypointMatch) {
      return `Missing waypoint (${waypointMatch[1]})`;
    }
    return 'Missing waypoint';
  }
  
  // Check for pods equality issues
  if (nextLines.includes('expected \'client-') && nextLines.includes('to equal \'waypoint-')) {
    const match = nextLines.match(/expected '([^']+)' to equal '([^']+)'/);
    if (match) {
      return `Wrong X-Istio-Workload header (expected ${match[2]})`;
    }
  }

  // Check for undefined waypoint
  if (nextLines.includes('expected undefined to equal \'waypoint-')) {
    const match = nextLines.match(/expected undefined to equal '([^']+)'/);
    if (match) {
      return `Missing waypoint (${match[1]})`;
    }
  }
  
  // Check for specific HTTP status codes
  if (nextLines.includes('expected 503 to equal 200')) {
    return 'Service unavailable (503)';
  } else if (nextLines.includes('expected 504 to equal 200')) {
    return 'Gateway timeout (504)';
  } else if (nextLines.includes('expected 403 to equal 200')) {
    return 'Access forbidden (403)';
  } else if (nextLines.includes('expected 404 to equal 200')) {
    return 'Not found (404)';
  } else if (nextLines.includes('expected 502 to equal 200')) {
    return 'Bad gateway (502)';
  }
  
  // Check for JSON parsing issues
  if (nextLines.includes('SyntaxError: Unexpected')) {
    return 'JSON parse error';
  }
  
  // Check for auth issues
  if (nextLines.includes('status" of 403') || nextLines.includes('isn\'t allowed to send POST requests')) {
    return 'Auth policy blocking';
  }
  
  // Check for timeout issues
  if (nextLines.includes('Timeout of')) {
    const timeoutMatch = nextLines.match(/Timeout of (\d+)ms/);
    return timeoutMatch ? `Timeout (${timeoutMatch[1]}ms)` : 'Timeout';
  }
  
  // Check for connection issues
  if (nextLines.includes('Connection refused')) {
    return 'Connection refused';
  } else if (nextLines.includes('ECONNRESET')) {
    return 'Connection reset';
  }

  // Check for headers/response missing expected content 
  if (nextLines.includes('expected \'{\n  "args": {}')) {
    return 'Response missing expected content';
  }
  
  return 'Test failed';
}

/**
 * Extract failures in ingress to waypoint tests
 */
function extractIngressWaypointFailures(section) {
  const tests = [];
  const foundTests = new Set(); // Track tests we've already found
  
  // Pattern for failing tests like "Ingress => LOCAL_ISTIO_WAYPOINT => /remote-in-ambient"
  const failRegex = /Ingress => (LOCAL|REMOTE)_(ISTIO|GLOO)_WAYPOINT => \/([^:\s]+)/g;
  
  // Look for failures in AssertionError messages
  let match;
  while ((match = failRegex.exec(section)) !== null) {
    // Only consider if this line is part of a failing test report
    const surroundingText = section.substring(Math.max(0, match.index - 200), 
                                             Math.min(section.length, match.index + 500));
    
    // Check if this is in an AssertionError context
    if (surroundingText.includes('AssertionError') || surroundingText.includes('failing')) {
      const waypointType = match[1].toLowerCase();
      const waypointProvider = match[2] === 'ISTIO' ? 'Istio' : 'Gloo';
      const destination = sanitizeString(match[3]);
      
      // Determine ingress type from context
      let ingressType = 'Istio Ingress'; // Default
      if (surroundingText.includes('from gloo ingress')) {
        ingressType = 'Gloo Ingress';
      }
      
      // Create a key to track this test
      const testKey = `${ingressType}-${destination}-${waypointType}-${waypointProvider}`;
      
      // Skip this test if we've already found it
      if (foundTests.has(testKey)) continue;
      foundTests.add(testKey);
      
      // Extract the specific error message
      const errorMsg = extractErrorMessage(surroundingText, 0);
      
      tests.push({
        ingressType,
        destination,
        waypointType,
        waypoint: waypointProvider,
        result: `❌ ${errorMsg}`
      });
    }
  }
  
  // Also catch tests from descriptions that don't have the exact format above
  const testDescRegex = /Tests all possible communication from (istio|gloo) ingress \(Local Waypoint=([^,]+), Remote Waypoint=([^,]+), Failover=([^,]+), Authorization Policy=([^,\)]+)\)/g;
  
  while ((match = testDescRegex.exec(section)) !== null) {
    // Check if the lines following this have a failure
    const nextLines = section.substring(match.index, Math.min(section.length, match.index + 2000));
    
    // If there's an assertion error following this test description
    if (nextLines.includes('AssertionError') && !nextLines.includes('passing')) {
      // Extract destination from assertion context
      const destMatch = nextLines.match(/X-Envoy-Original-Path": "\/([^\/]+)\/get"/);
      if (destMatch) {
        const ingressType = match[1] === 'istio' ? 'Istio Ingress' : 'Gloo Ingress';
        const localWaypoint = match[2] !== 'None' ? match[2] : '-';
        const destination = sanitizeString(destMatch[1]);
        
        // Create a key to track this test
        const testKey = `${ingressType}-${destination}-local-${localWaypoint}`;
        
        // Skip this test if we've already found it
        if (foundTests.has(testKey)) continue;
        foundTests.add(testKey);
        
        // If local waypoint is present, this is likely a waypoint test
        if (localWaypoint !== '-') {
          // Extract the specific error message
          const errorMsg = extractErrorMessage(nextLines, 0);
          
          tests.push({
            ingressType,
            destination,
            waypointType: 'local',
            waypoint: localWaypoint,
            result: `❌ ${errorMsg}`
          });
        }
      }
    }
  }
  
  return tests;
}

// Example usage
const logFilePath = process.argv[2] || './out-copy.log';
if (!fs.existsSync(logFilePath)) {
  console.error(`File not found: ${logFilePath}`);
  process.exit(1);
}

const markdownTable = generateTableFromLog(logFilePath);
console.log(markdownTable);

// Optionally write to a file
if (process.argv[3]) {
  fs.writeFileSync(process.argv[3], markdownTable);
  console.log(`Table written to ${process.argv[3]}`);
}