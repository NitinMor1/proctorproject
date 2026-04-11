const mongoose = require('mongoose');

const violationSchema = new mongoose.Schema({
  session: { type: mongoose.Schema.Types.ObjectId, ref: 'Session', required: true },
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { 
    type: String, 
    enum: [
      'FACE_NOT_DETECTED', 
      'MULTIPLE_FACES', 
      'LOOKING_AWAY', 
      'TAB_SWITCHED', 
      'FULLSCREEN_EXIT',
      'AUDIO_DETECTED'
    ], 
    required: true 
  },
  severity: { type: String, enum: ['low', 'medium', 'high'], default: 'low' },
  timestamp: { type: Date, default: Date.now },
  comment: { type: String },
  screenshotUrl: { type: String } // Optional: Store screenshot of violation
});

module.exports = mongoose.model('Violation', violationSchema);
