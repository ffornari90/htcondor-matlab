var args = require('system').args;
var page = require('webpage').create();
var fs = require('fs');
var cookieJarFilePath = '/tmp/cookies.txt';
var iamServer = args[1];

page.viewportSize = {
  width: 1920,
  height: 1080
};

writeCookiesToFile = function() {
  cookieJar = [];
  for(var j in phantom.cookies) {
    cookieJar.push({
      name: phantom.cookies[j].name,
      value: phantom.cookies[j].value,
      domain: phantom.cookies[j].domain,
      path: phantom.cookies[j].path,
      httponly: phantom.cookies[j].httponly,
      secure: phantom.cookies[j].secure,
      expires: phantom.cookies[j].expires
    });
  }

  if(!fs.isFile(cookieJarFilePath)){
    fs.write(cookieJarFilePath, JSON.stringify(cookieJar), 'w');
        }
};

page.open('https://' + iamServer, function(status) {
  this.evaluate(function() {
    document.querySelector("#x509-login > a").click();
  });

  setTimeout(function(){
      writeCookiesToFile();
      phantom.exit();
  }, 1);

});
