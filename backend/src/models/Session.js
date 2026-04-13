const mongoose = require('mongoose');

const sessionSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  examId: { type: mongoose.Schema.Types.ObjectId, ref: 'Exam', required: true },
  startTime: { type: Date, default: Date.now },
  endTime: { type: Date },
  status: { type: String, enum: ['active', 'completed', 'flagged'], default: 'active' },
  integrityScore: { type: Number, default: 100 },
  totalViolations: { type: Number, default: 0 },
  violationCounts: {
    FACE_NOT_DETECTED: { type: Number, default: 0 },
    MULTIPLE_FACES:    { type: Number, default: 0 },
    LOOKING_AWAY:      { type: Number, default: 0 },
    TAB_SWITCHED:      { type: Number, default: 0 },
    FULLSCREEN_EXIT:   { type: Number, default: 0 },
    AUDIO_DETECTED:    { type: Number, default: 0 },
  },
  logs: [{
    timestamp: { type: Date, default: Date.now },
    event: String
  }]
});

module.exports = mongoose.model('Session', sessionSchema);
