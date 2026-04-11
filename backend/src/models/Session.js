const mongoose = require('mongoose');

const sessionSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  examId: { type: String, required: true },
  startTime: { type: Date, default: Date.now },
  endTime: { type: Date },
  status: { type: String, enum: ['active', 'completed', 'flagged'], default: 'active' },
  integrityScore: { type: Number, default: 100 },
  totalViolations: { type: Number, default: 0 },
  logs: [{
    timestamp: { type: Date, default: Date.now },
    event: String
  }]
});

module.exports = mongoose.model('Session', sessionSchema);
