const keycloak = require('./keycloak');
const { argv } = require('node:process');

keycloak.getKeyCloakCookie(argv[2], argv[3]);
