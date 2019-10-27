'use strict';

const express = require('express');

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

const COLORS = ['blue', 'red', 'green', 'magenta', 'orange'];

// App
const app = express();
app.get('/', (req, res) => {
  let color = COLORS[Math.floor(Math.random() * COLORS.length)];
  res.send({color: color});
});

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
