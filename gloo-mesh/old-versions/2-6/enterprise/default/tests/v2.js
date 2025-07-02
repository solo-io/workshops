const axios = require('axios');
const https = require('https');
const fs = require('fs');
const { execSync } = require('child_process');
const { JSONPath } = require('jsonpath-plus');

/**
 * Builds kubectl command argument parts for resource selection
 * @param {object} selector - The Kubernetes selector
 * @returns {object} - Object containing command argument parts
 */
const buildSelectorArgs = (selector) => {
  // Determine the resource kind
  const kindArg = selector.kind.toLowerCase();
  
  // Add namespace if specified
  const namespaceArg = selector.metadata.namespace ? `-n ${selector.metadata.namespace}` : '';
  
  // Add context if specified
  const contextArg = selector.context ? `--context=${selector.context}` : '';
  
  // Determine the selection method (name or labels)
  let selectorArg = '';
  if (selector.metadata.name) {
    selectorArg = selector.metadata.name;
  } else if (selector.metadata.labels && Object.keys(selector.metadata.labels).length > 0) {
    const labelSelectors = Object.entries(selector.metadata.labels)
      .map(([key, value]) => `${key}=${value}`)
      .join(',');
    selectorArg = `-l ${labelSelectors}`;
  } else {
    throw new Error('Either metadata.name or metadata.labels must be provided in Kubernetes selector');
  }
  
  return {
    kindArg,
    namespaceArg,
    selectorArg,
    contextArg
  };
}

module.exports = {
  executeHttpTest,
  executeKubectlWait
};

/**
 * Deep comparison of two values (objects, arrays, primitives)
 */
function deepCompare(obj1, obj2) {
  // Direct equality
  if (obj1 === obj2) return true;
  
  // If either value is not an object or is null
  if (typeof obj1 !== 'object' || obj1 === null || 
      typeof obj2 !== 'object' || obj2 === null) {
    return false;
  }
  
  // Check if both are arrays
  if (Array.isArray(obj1) && Array.isArray(obj2)) {
    if (obj1.length !== obj2.length) return false;
    
    for (let i = 0; i < obj1.length; i++) {
      if (!deepCompare(obj1[i], obj2[i])) return false;
    }
    
    return true;
  }
  
  // If one is an array but the other isn't
  if (Array.isArray(obj1) || Array.isArray(obj2)) return false;
  
  // Compare object properties
  const keys1 = Object.keys(obj1);
  const keys2 = Object.keys(obj2);
  
  if (keys1.length !== keys2.length) return false;
  
  for (const key of keys1) {
    if (!keys2.includes(key)) return false;
    if (!deepCompare(obj1[key], obj2[key])) return false;
  }
  
  return true;
}

/**
 * Sleep function for async/await
 */
async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Compare a value against an expected value using specified comparator
 * @param {any} actual - The actual value to check
 * @param {object} comparison - The comparison configuration
 * @param {string} description - Optional description for logging
 * @returns {boolean} - Whether the comparison succeeded
 */
function compareValue(actual, comparison, description = 'Value') {
  // Convert non-string values to string for contains and matches operations
  const actualAsString = typeof actual === 'string' ? actual : JSON.stringify(actual);
  let result = false;
  
  switch (comparison.comparator) {
    case 'exists':
      result = actual !== undefined && actual !== null;
      console.debug(`${description} ${comparison.negate ? 'should not exist' : 'should exist'}: ${result ? 'exists' : 'does not exist'}`);
      break;
      
    case 'equals':
      result = deepCompare(actual, comparison.value);
      console.debug(`${description} ${comparison.negate ? 'should not equal' : 'should equal'} ${JSON.stringify(comparison.value)}: ${result ? 'match' : 'no match'}`);
      break;
      
    case 'contains':
      result = actualAsString.includes(String(comparison.value));
      console.debug(`${description} ${comparison.negate ? 'should not contain' : 'should contain'} "${comparison.value}": ${result ? 'contains' : 'does not contain'}`);
      break;
      
    case 'matches':
      result = new RegExp(comparison.value).test(actualAsString);
      console.debug(`${description} ${comparison.negate ? 'should not match' : 'should match'} /${comparison.value}/: ${result ? 'matches' : 'does not match'}`);
      break;
      
    default:
      console.error(`Unknown comparator: ${comparison.comparator}`);
      return false;
  }
  
  // If negate is true, invert the result
  return comparison.negate ? !result : result;
}

/**
 * HTTP test executor - maintains the same interface as in the test framework
 * @param {object} test - The test configuration
 * @returns {Promise<boolean>} - Promise resolving to whether the test passed
 */
async function executeHttpTest(test) {
  if (!test.http) {
    throw new Error('HTTP configuration missing for HTTP test');
  }

  // Create a descriptive test name
  let testName = `${test.http.method} ${test.http.url}${test.http.path}`;
  if (test.source.type === 'pod' && test.source.selector) {
    testName += ` (via pod ${test.source.selector.metadata.namespace || 'default'}/${test.source.selector.metadata.name || '<selector>'})`;
  }
  
  try {
    console.debug(`Executing HTTP test: ${testName}`);
    console.debug(`Request details: ${JSON.stringify({
      method: test.http.method,
      url: test.http.url + test.http.path,
      headers: test.http.headers || {},
      body: test.http.body || null,
      sourceType: test.source.type
    }, null, 2)}`);
    
    let response;
    
    if (test.source.type === 'local') {
      console.debug('Using local HTTP client');
      response = await executeLocalHttpRequest(test.http);
    } else if (test.source.type === 'pod') {
      if (!test.source.selector) {
        throw new Error('Kubernetes selector is required for pod-based tests');
      }
      
      console.debug(`Using kubectl debug to access pod ${JSON.stringify(test.source.selector)}`);
      response = await executePodHttpRequest(test);
    } else {
      throw new Error(`Unsupported source type: ${test.source.type}`);
    }

    // Log the response details at debug level
    console.debug(`Response received: ${JSON.stringify({
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body
    }, null, 2)}`);

    // Validate expectations
    const success = validateHttpExpectations(response, test.expect, testName);
    
    if (success) {
      console.debug(`Test passed: ${testName}`);
    } else {
      console.error(`Test failed: ${testName}`);
    }
    
    return success;
  } catch (error) {
    console.error(`Test failed with error: ${testName}`);
    console.error(error?.message || String(error));
    return false;
  }
}

/**
 * Execute an HTTP request locally
 * @param {object} httpConfig - The HTTP request configuration
 * @returns {Promise<object>} - The response object
 */
async function executeLocalHttpRequest(httpConfig) {
  console.debug(`Executing local HTTP request: ${httpConfig.method} ${httpConfig.url}${httpConfig.path}`);
  
  // Configure HTTPS Agent with certificates if provided
  let httpsAgent;
  if (httpConfig.url.startsWith('https://')) {
    const agentOptions = {
      rejectUnauthorized: !httpConfig.skipSslVerification
    };
    
    // Add certificate and key if provided
    if (httpConfig.cert || httpConfig.key || httpConfig.ca) {
      console.debug('Using SSL certificates for HTTPS request');
      
      if (httpConfig.cert) {
        try {
          agentOptions.cert = fs.readFileSync(httpConfig.cert);
          console.debug(`Loaded certificate from ${httpConfig.cert}`);
        } catch (error) {
          console.error(`Failed to read certificate file: ${error}`);
          throw new Error(`Failed to read certificate file: ${error}`);
        }
      }
      
      if (httpConfig.key) {
        try {
          agentOptions.key = fs.readFileSync(httpConfig.key);
          console.debug(`Loaded key from ${httpConfig.key}`);
        } catch (error) {
          console.error(`Failed to read key file: ${error}`);
          throw new Error(`Failed to read key file: ${error}`);
        }
      }
      
      if (httpConfig.ca) {
        try {
          agentOptions.ca = fs.readFileSync(httpConfig.ca);
          console.debug(`Loaded CA certificate from ${httpConfig.ca}`);
        } catch (error) {
          console.error(`Failed to read CA certificate file: ${error}`);
          throw new Error(`Failed to read CA certificate file: ${error}`);
        }
      }
    }
    
    httpsAgent = new https.Agent(agentOptions);
  }
  
  if (httpConfig.skipSslVerification) {
    console.debug(`SSL certificate verification is disabled`);
  }

  try {
    const response = await axios({
      method: httpConfig.method.toLowerCase(),
      url: `${httpConfig.url}${httpConfig.path}`,
      headers: httpConfig.headers || {},
      data: httpConfig.body,
      httpsAgent,
      validateStatus: () => true // Don't throw error on non-2xx status codes
    });

    console.debug(`Response received with status code: ${response.status}`);
    
    return {
      statusCode: response.status,
      headers: response.headers,
      body: response.data,
    };
  } catch (error) {
    console.error(`Request failed: ${error.message}`);
    throw error;
  }
}

/**
 * Execute an HTTP request from within a Kubernetes pod
 * @param {object} test - The test configuration
 * @returns {Promise<object>} - The response object
 */
async function executePodHttpRequest(test) {
  if (!test.source.selector || !test.http) {
    throw new Error('Kubernetes selector and HTTP configuration are required for pod tests');
  }

  const selector = test.source.selector;
  const container = test.source.container;
  const httpConfig = test.http;
  
  try {
    console.debug(`Executing HTTP request via pod: ${httpConfig.method} ${httpConfig.url}${httpConfig.path}`);
    
    // Execute the Node.js HTTP request in the pod
    const stdout = await debugPodWithHttpRequest(
      { ...selector, kind: 'Pod' }, // Ensure kind is set to Pod
      httpConfig,
      container
    );
    
    console.debug(`Debug output raw length: ${stdout.length} bytes`);
    
    try {
      // Find the JSON response in the output using regex to be more robust
      const responseRegex = /HTTP_RESPONSE_START\s+([\s\S]*?)\s+HTTP_RESPONSE_END/;
      const match = stdout.match(responseRegex);
      
      if (!match || !match[1]) {
        console.error(`Full pod debug output:\n${stdout}`);
        throw new Error('Could not find HTTP response markers in the output');
      }
      
      const jsonResponse = match[1].trim();
      console.debug(`Extracted JSON response (${jsonResponse.length} bytes)`);
      
      try {
        const response = JSON.parse(jsonResponse);
        console.debug(`Successfully parsed response from pod execution`);
        return response;
      } catch (jsonError) {
        console.error(`Failed to parse JSON: ${jsonError.message}`);
        console.error(`JSON content: ${jsonResponse}`);
        throw new Error(`Failed to parse JSON response: ${jsonError.message}`);
      }
    } catch (parseError) {
      console.error(`Failed to parse response: ${parseError.message || String(parseError)}`);
      throw new Error(`Failed to parse response: ${parseError.message || String(parseError)}`);
    }
  } catch (error) {
    console.error(`Failed to execute pod-based request: ${error?.message || String(error)}`);
    throw new Error(`Failed to execute pod-based request: ${error?.message || String(error)}`);
  }
}

/**
 * Execute a kubectl debug with a Node.js HTTP request
 * @param {object} selector - The Kubernetes selector
 * @param {object} httpConfig - The HTTP configuration
 * @param {string} container - Optional target container name
 * @returns {Promise<string>} - The command output
 */
async function debugPodWithHttpRequest(selector, httpConfig, container) {
  if (!selector.metadata.namespace) {
    throw new Error('Namespace is required in the Kubernetes selector');
  }

  const namespace = selector.metadata.namespace;
  const context = selector.context;
  
  try {
    // Get a human-readable resource description for logs
    const resourceDescription = getResourceDescription(selector);
    console.debug(`Finding pod for ${resourceDescription}`);
    
    let podName;
    
    // If a specific pod name is given
    if (selector.metadata.name) {
      podName = selector.metadata.name;
      console.debug(`Using specified pod name: ${podName}`);
    } 
    // Otherwise, use label selectors to find a pod
    else if (selector.metadata.labels && Object.keys(selector.metadata.labels).length > 0) {
      // Build kubectl command to get pod name
      const labelSelector = labelsToSelectorString(selector.metadata.labels);
      const getPodCmd = `kubectl ${context ? `--context=${context}` : ''} -n ${namespace} get pods -l ${labelSelector} -o jsonpath='{.items[0].metadata.name}'`;
      console.debug(`Pod finder command: ${getPodCmd}`);
      
      try {
        const podOutput = execSync(getPodCmd, { encoding: 'utf8' });
        podName = podOutput.trim().replace(/^'|'$/g, ''); // Remove any quotes
      } catch (e) {
        throw new Error(`Failed to find pod with labels ${labelSelector} in namespace ${namespace}: ${e.message}`);
      }
      
      if (!podName) {
        throw new Error(`No pods found matching labels ${labelSelector} in namespace ${namespace}`);
      }
      
      console.debug(`Found pod ${podName} for ${resourceDescription}`);
    } else {
      throw new Error('Either metadata.name or metadata.labels must be provided in Kubernetes selector for pod debug');
    }
    
    // Create a temporary file with the Node.js HTTP request script
    const tempScriptPath = `/tmp/pod-http-request-${Date.now()}.js`;
    const script = createHttpRequestScript(httpConfig);
    
    fs.writeFileSync(tempScriptPath, script, 'utf8');
    console.debug(`Created temporary script at ${tempScriptPath}`);
    
    try {
      // Execute debug command on the found pod with the script
      return await debugPodWithScript(namespace, podName, tempScriptPath, context, container);
    } finally {
      // Clean up the temporary file
      try {
        fs.unlinkSync(tempScriptPath);
        console.debug(`Removed temporary script ${tempScriptPath}`);
      } catch (cleanupError) {
        console.warn(`Failed to clean up temporary script: ${cleanupError.message}`);
      }
    }
  } catch (error) {
    console.error(`Failed to debug pod for selector ${selector.kind}/${selector.metadata.namespace || 'default'}: ${error?.message || String(error)}`);
    throw new Error(`Failed to debug pod for selector: ${error?.message || String(error)}`);
  }
}

/**
 * Create a Node.js script for HTTP request
 * @param {object} httpConfig - The HTTP configuration
 * @returns {string} - The script content
 */
function createHttpRequestScript(httpConfig) {
  return `
const http = require('http');
const https = require('https');
const url = require('url');
const fs = require('fs');

// Process URL
const fullUrl = "${httpConfig.url}${httpConfig.path}";
const parsedUrl = url.parse(fullUrl);
const isHttps = parsedUrl.protocol === 'https:';

// Prepare request options
const options = {
  hostname: parsedUrl.hostname,
  port: parsedUrl.port || (isHttps ? 443 : 80),
  path: parsedUrl.pathname + (parsedUrl.search || ''),
  method: "${httpConfig.method.toUpperCase()}",
  headers: ${JSON.stringify(httpConfig.headers || {})},
};

${httpConfig.skipSslVerification ? 'options.rejectUnauthorized = false;' : ''}

${httpConfig.cert ? `// Certificate handling would go here in production code` : ''}
${httpConfig.key ? `// Key handling would go here in production code` : ''}
${httpConfig.ca ? `// CA certificate handling would go here in production code` : ''}

console.log("Starting HTTP request to " + fullUrl);

// Create request
const req = (isHttps ? https : http).request(options, (res) => {
  let data = "";
  
  // Collect response data
  res.on("data", (chunk) => {
    data += chunk;
  });
  
  // Process complete response
  res.on("end", () => {
    const headers = res.headers;
    let body;
    
    // Try to parse as JSON
    try {
      body = JSON.parse(data);
      console.log("Parsed response as JSON");
    } catch (e) {
      body = data;
      console.log("Keeping response as string");
    }
    
    // Create response object
    const response = {
      statusCode: res.statusCode,
      headers: headers,
      body: body
    };
    
    // Output the response with markers for easy extraction
    console.log("HTTP_RESPONSE_START");
    console.log(JSON.stringify(response));
    console.log("HTTP_RESPONSE_END");
  });
});

// Handle errors
req.on("error", (error) => {
  console.error("Error making request:", error.message);
  console.log("HTTP_RESPONSE_START");
  console.log(JSON.stringify({
    error: true,
    message: error.message,
    statusCode: 0,
    headers: {},
    body: null
  }));
  console.log("HTTP_RESPONSE_END");
});

// Add body if applicable
${httpConfig.body ? 
  `const bodyData = ${JSON.stringify(typeof httpConfig.body === 'string' ? 
    httpConfig.body : 
    JSON.stringify(httpConfig.body))};
req.write(bodyData);
console.log("Added request body");` : 
  '// No body to add'}

// Send the request
req.end();
console.log("Request sent, waiting for response...");
`;
}

/**
 * Execute a kubectl debug command on a pod with the provided script
 * @param {string} namespace - The namespace of the pod
 * @param {string} podName - The name of the pod
 * @param {string} scriptPath - Path to the script file
 * @param {string} context - Optional Kubernetes context
 * @param {string} container - Optional target container name
 * @returns {Promise<string>} - The command output
 */
async function debugPodWithScript(namespace, podName, scriptPath, context, container) {
  try {
    console.debug(`Debugging pod ${namespace}/${podName} to execute HTTP request`);
    
    // Copy the script to the pod using kubectl cp
    const tempPodScript = '/tmp/http-request.js';
    
    // Build debug command
    let debugCmd = `kubectl debug -it`;
    
    if (context) {
      debugCmd += ` --context=${context}`;
    }
    
    debugCmd += ` -n ${namespace} ${podName}`;
    debugCmd += ` --image=node:slim`;
    
    if (container) {
      debugCmd += ` --target=${container}`;
    }
    
    // Create a safe command that copies our script into the pod and runs it
    debugCmd += ` -- /bin/bash -c "cat > ${tempPodScript} << 'EOFSCRIPT'
$(cat ${scriptPath})
EOFSCRIPT
node ${tempPodScript}"`;
    
    console.debug(`Executing debug command with script`);
    
    const stdout = execSync(debugCmd, { 
      encoding: 'utf8',
      maxBuffer: 10 * 1024 * 1024 // 10MB buffer for potentially large responses
    });
    
    return stdout;
  } catch (error) {
    console.error(`Failed to debug pod ${namespace}/${podName}: ${error?.message || String(error)}`);
    throw new Error(`Failed to debug pod ${namespace}/${podName}: ${error?.message || String(error)}`);
  }
}

/**
 * Validate HTTP expectations against a response
 * @param {object} response - The HTTP response
 * @param {object} expect - The expectations
 * @param {string} testName - The test name for logging
 * @returns {boolean} - Whether all expectations are met
 */
function validateHttpExpectations(
  response,
  expect,
  testName
) {
  console.debug(`Validating expectations for: ${testName}`);

  // 1) Status code
  if (response.statusCode !== expect.statusCode) {
    console.error(`Status code mismatch: expected ${expect.statusCode}, got ${response.statusCode}`);
    return false;
  }
  console.debug(`✓ Status code matches: ${response.statusCode}`);

  const rawBody = typeof response.body === 'string'
    ? response.body
    : JSON.stringify(response.body);

  // 2) Exact body
  if (expect.body !== undefined) {
    if (!deepCompare(response.body, expect.body)) {
      console.error(`Body mismatch (exact):`);
      console.error({ expected: expect.body, received: response.body });
      return false;
    }
    console.debug(`✓ Body exactly matches`);
  }

  // 3) Substring
  if (expect.bodyContains) {
    const containsNegate = typeof expect.bodyContains === 'object' && 'negate' in expect.bodyContains;
    const containsValue = containsNegate ? expect.bodyContains.value : expect.bodyContains;
    const negate = containsNegate ? expect.bodyContains.negate : false;
    
    const contains = rawBody.includes(containsValue);
    if (negate ? contains : !contains) {
      const message = negate 
        ? `Body should not contain substring but does: "${containsValue}"` 
        : `Body does not contain substring: "${containsValue}"`;
      console.error(message);
      return false;
    }
    
    const successMsg = negate 
      ? `✓ Body does not contain "${containsValue}"` 
      : `✓ Body contains "${containsValue}"`;
    console.debug(successMsg);
  }

  // 4) Regex
  if (expect.bodyRegex) {
    const regexNegate = typeof expect.bodyRegex === 'object' && 'negate' in expect.bodyRegex;
    const regexValue = regexNegate ? expect.bodyRegex.value : expect.bodyRegex;
    const negate = regexNegate ? expect.bodyRegex.negate : false;
    
    const re = new RegExp(regexValue);
    const matches = re.test(rawBody);
    if (negate ? matches : !matches) {
      const message = negate 
        ? `Body should not match regex but does: ${regexValue}` 
        : `Body does not match regex: ${regexValue}`;
      console.error(message);
      return false;
    }
    
    const successMsg = negate 
      ? `✓ Body does not match regex ${regexValue}` 
      : `✓ Body matches regex ${regexValue}`;
    console.debug(successMsg);
  }

  // 5) JSONPath expectations
  if (expect.bodyJsonPath) {
    for (const jp of expect.bodyJsonPath) {
      const results = JSONPath({ path: jp.path, json: response.body });
      if (results.length === 0) {
        if (jp.negate && jp.comparator === 'exists') {
          console.debug(`✓ JSONPath "${jp.path}" does not exist, as expected`);
          continue;
        }
        console.error(`JSONPath "${jp.path}" did not return any results`);
        return false;
      }
      
      // Use the comparison utility
      if (!compareValue(results[0], jp, `JSONPath ${jp.path}`)) {
        return false;
      }
      
      const successMsg = jp.negate 
        ? `✓ JSONPath ${jp.path} ${jp.comparator} NOT ${jp.value}` 
        : `✓ JSONPath ${jp.path} ${jp.comparator} ${jp.value}`;
      console.debug(successMsg);
    }
  }

  // 6) Header validation with operators
  if (expect.headers && expect.headers.length > 0) {
    for (const headerExp of expect.headers) {
      const headerName = headerExp.name.toLowerCase(); // Headers are case-insensitive
      const headerValue = response.headers[headerName];
      
      // For 'exists' comparator, check if the header exists
      if (headerExp.comparator === 'exists') {
        const result = compareValue(headerValue, headerExp, `Header "${headerExp.name}"`);
        if (!result) return false;
        
        const existsSuccessMsg = headerExp.negate 
          ? `✓ Header "${headerExp.name}" does not exist, as expected` 
          : `✓ Header "${headerExp.name}" exists`;
        console.debug(existsSuccessMsg);
        continue;
      }
      
      // For other comparators, first check if the header exists
      if (headerValue === undefined) {
        console.error(`Header "${headerExp.name}" not found in response`);
        return false;
      }
      
      // Use the comparison utility
      if (!compareValue(headerValue, headerExp, `Header "${headerExp.name}"`)) {
        return false;
      }
      
      const opString = headerExp.negate ? `does not ${headerExp.comparator}` : headerExp.comparator;
      console.debug(`✓ Header "${headerExp.name}" ${opString} "${headerExp.value}"`);
    }
  }

  return true;
}

/**
 * Converts labels to a selector string for kubectl
 * @param {object} labels - The labels object
 * @returns {string} - The selector string
 */
function labelsToSelectorString(labels) {
  return Object.entries(labels)
    .map(([key, value]) => `${key}=${value}`)
    .join(',');
}

/**
 * Gets a human-readable description of the resource being selected
 * @param {object} selector - The Kubernetes selector
 * @returns {string} - The resource description
 */
function getResourceDescription(selector) {
  const kind = selector.kind;
  const namespace = selector.metadata.namespace || 'default';
  const name = selector.metadata.name || 
                (selector.metadata.labels ? 
                `with labels ${Object.entries(selector.metadata.labels)
                  .map(([k, v]) => `${k}=${v}`).join(',')}` : 
                'unknown');
                
  return `${kind}/${namespace}/${name}`;
}

/**
 * Waits for a Kubernetes resource to match a condition
 * @param {object} config - Configuration for the wait operation
 * @returns {Promise<void>} - Promise that resolves when the condition is met or rejects with an error
 */
async function executeKubectlWait(config) {
  if (!config.target) throw new Error('target block required for kubectl-wait');

  const { target, jsonPath, jsonPathExpectation, targetEnv, polling } = config;
  
  // Get kubectl selector args
  const selectorArgs = buildSelectorArgs(target);
  const { kindArg, namespaceArg, selectorArg, contextArg } = selectorArgs;

  const timeout = polling?.timeoutSeconds ?? 60;
  const interval = polling?.intervalSeconds ?? 2;
  const maxRetries = polling?.maxRetries; // undefined means unlimited retries
  
  // Get a human-readable description of the resource
  const resourceDescription = getResourceDescription(target);

  // Log what we're waiting for
  if (jsonPathExpectation) {
    const compareStr = jsonPathExpectation.negate 
      ? `not ${jsonPathExpectation.comparator}` 
      : jsonPathExpectation.comparator;
    const valueStr = jsonPathExpectation.comparator !== 'exists' 
      ? ` ${JSON.stringify(jsonPathExpectation.value)}` 
      : '';
    
    // Include retry info in log message if specified
    const retryInfo = maxRetries !== undefined ? ` (max ${maxRetries} retries)` : '';
    console.info(`Waiting for ${resourceDescription} until ${jsonPath} ${compareStr}${valueStr}${retryInfo}`);
  } else {
    const retryInfo = maxRetries !== undefined ? ` (max ${maxRetries} retries)` : '';
    console.info(`Waiting for ${resourceDescription}${retryInfo}`);
  }

  const deadline = Date.now() + timeout * 1000;
  let retryCount = 0;
  
  while (Date.now() < deadline) {
    // Check if we've exceeded max retries
    if (maxRetries !== undefined && retryCount >= maxRetries) {
      const retriesExceededMsg = `Maximum retries (${maxRetries}) exceeded while waiting for ${resourceDescription}`;
      console.error(retriesExceededMsg);
      throw new Error(retriesExceededMsg);
    }
    
    try {
      // Build kubectl command with the selector args
      const cmd = `kubectl ${contextArg} ${namespaceArg} get ${kindArg} ${selectorArg} -o json`;
      console.debug(`kubectl-get: ${cmd}`);
      
      // Execute the command
      const stdout = execSync(cmd, { encoding: 'utf8' });

      if (!stdout.trim()) { 
        console.debug(`Attempt ${retryCount + 1}${maxRetries !== undefined ? `/${maxRetries}` : ''}: No output from kubectl command`);
        retryCount++;
        await sleep(interval * 1000);
        continue;
      }

      const json = JSON.parse(stdout);
      if (!json) {
        console.debug(`Attempt ${retryCount + 1}${maxRetries !== undefined ? `/${maxRetries}` : ''}: Invalid JSON response`);
        retryCount++;
        await sleep(interval * 1000);
        continue;
      }

      // Only extract the value if jsonPath is provided
      if (jsonPath) {
        const matches = JSONPath({ path: jsonPath, json: json });
        if (!matches.length || matches[0] === null || matches[0] === undefined) {
          console.debug(`Attempt ${retryCount + 1}${maxRetries !== undefined ? `/${maxRetries}` : ''}: jsonPath ${jsonPath} not found yet, retrying…`);
          retryCount++;
          await sleep(interval * 1000);
          continue;
        }

        const extractedValue = matches[0];
        
        // Check against expected conditions if provided
        if (jsonPathExpectation) {
          // Use the compare value function
          const result = compareValue(
            extractedValue, 
            jsonPathExpectation,
            `JSONPath ${jsonPath}`
          );
          
          if (!result) {
            console.debug(`Attempt ${retryCount + 1}${maxRetries !== undefined ? `/${maxRetries}` : ''}: Value does not meet expectation yet, retrying...`);
            retryCount++;
            await sleep(interval * 1000);
            continue;
          }
          
          console.debug(`Value meets expectation: ${JSON.stringify(extractedValue)}`);
        } else {
          // No expectation - just checking if the value exists and is not empty
          if (extractedValue === '') {
            console.debug(`Attempt ${retryCount + 1}${maxRetries !== undefined ? `/${maxRetries}` : ''}: Value is empty string, retrying...`);
            retryCount++;
            await sleep(interval * 1000);
            continue;
          }
          console.debug(`Found value for ${jsonPath}: ${typeof extractedValue === 'string' ? extractedValue : JSON.stringify(extractedValue)}`);
        }
        
        // Only set environment variable if targetEnv is provided
        if (targetEnv) {
          const valueToSet = typeof extractedValue === 'string' ? extractedValue : JSON.stringify(extractedValue);
          console.debug(`Setting environment variable ${targetEnv}=${valueToSet}`);
          process.env[targetEnv] = valueToSet;
        }
      } else {
        // If no jsonPath is provided, we just wait for the resource to exist
        console.debug(`Resource ${resourceDescription} exists`);
      }
      
      return;
    } catch (err) {
      console.debug(`Attempt ${retryCount + 1}${maxRetries !== undefined ? `/${maxRetries}` : ''}: lookup failed, will retry: ${err.message}`);
      retryCount++;
      await sleep(interval * 1000);
    }
  }
  
  // Format a helpful error message for timeout
  let errorMessage = `Timed-out (${timeout}s) waiting for ${resourceDescription}`;
  if (jsonPath) {
    errorMessage += ` → ${jsonPath}`;
    if (jsonPathExpectation) {
      const op = jsonPathExpectation.negate ? `not ${jsonPathExpectation.comparator}` : jsonPathExpectation.comparator;
      const valueStr = jsonPathExpectation.comparator !== 'exists' 
        ? ` ${JSON.stringify(jsonPathExpectation.value)}` 
        : '';
      errorMessage += ` to ${op}${valueStr}`;
    }
  }
  
  throw new Error(errorMessage);
}
