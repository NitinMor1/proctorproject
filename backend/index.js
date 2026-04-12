require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./src/config/db');

// Connect to Database
connectDB();

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Routes
app.use('/api/auth', require('./src/routes/auth'));
app.use('/api/sessions', require('./src/routes/session'));
app.use('/api/violations', require('./src/routes/violation'));
app.use('/api/exams', require('./src/routes/exam'));
app.use('/api/submissions', require('./src/routes/submission'));
app.use('/api/admin', require('./src/routes/admin'));

app.get('/', (req, res) => {
  res.send('ProctorAI API is running...');
});

// Start Server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
