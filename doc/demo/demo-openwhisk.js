let url = 'https://openwhisk.ng.bluemix.net/api/v1/web/lmandel_dev/qcert/cloudant-compile-deploy.json'

const compileAndDeployButton = () => {
  const input = {
    'cloudant': {
      'username': getParameter('cloudant-username', ''),
      'password': getParameter('cloudant-password', '')
    },
    'whisk': {
      'api_key': getParameter('wsk-api_key', ''),
      'namespace': getParameter('wsk-namespace', ''),
    },
    'pkgname': getParameter('wsk-pkg', ''),
    'action': getParameter('wsk-action', ''),
    'source': getParameter("source", ""),
    'exactpath': getParameter("exactpath", "FillPath") === "ExactPath",
    'emitall': getParameter("emitall", "EmitTarget") === "EmitAll",
    'eval': false,
    'schema': getParameter("schema", "{}"),
    'input': getParameter("input", "{}"),
    'ascii': getParameter("charset", "Greek") === "Ascii",
    'javaimports': getParameter("java_imports", ""),
    'query': document.getElementById("query").value,
    'optims': getParameter("optim", "[]")
  };
  console.log('input =', input)
  document.getElementById("result").innerHTML = "[ Query is compiling ]";
  const success = function (result) {
    console.log('result = ', JSON.stringify(result));
    const resultUrl = 'https://openwhisk.ng.bluemix.net/api/v1/web/' +
      input.whisk.namespace + '/' + input.pkgname + '/' + input.action + '.json'
    document.getElementById("result").innerHTML =
      '<a href="' + resultUrl + '">' + resultUrl + '</a >'

  }
  const failure = () => {
    document.getElementById("result").innerHTML = "compilation or deployment failed";
  }
  const call = makeHandler(input, url, success, failure)
  call()
}


const makeHandler = (input, url, success, failure) => {
  return function () {
    console.log("Handler invoked on URL " + url);
    const request = new XMLHttpRequest();
    request.open("POST", url, true);
    request.setRequestHeader("Content-Type", "application/json");
    request.onloadend = function () {
      if (request.status == 200) {
        console.log("Success at url " + url);
        const response = JSON.parse(request.responseText);
        success(response);
      }
      else {
        console.log("Failure at url " + url);
        failure();
      }
    };
    try {
      console.log("Posting request on url " + url);
      request.send(JSON.stringify(input));
    } catch (e) {
    }
  };
}

const entityMap = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': '&quot;',
  "'": '&#39;',
  "/": '&#x2F;'
}

const escapeHtml = (string) => {
  return String(string).replace(/[&<>"'\/]/g, function (s) {
    return entityMap[s];
  });
}

const getParameter = (paramName, defaultValue) => {
  elem = document.getElementById(paramName);
  if (elem != null) {
    return elem.value;
  } else {
    return defaultValue;
  }
}
