'use strict';

const express = require('express');

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

const MIN_SIZE = 20;
const MAX_SIZE = 90;

// App
const app = express();
app.get('/', (req, res) => {
  let size = MIN_SIZE + Math.floor(Math.random() * Math.floor(MAX_SIZE - MIN_SIZE));
  res.send({size: size});
});

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
