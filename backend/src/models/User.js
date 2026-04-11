const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['student', 'admin'], default: 'student' },
  faceEmbedding: { type: [Number], required: true }, // 128D Embedding
  registeredAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('User', userSchema);
