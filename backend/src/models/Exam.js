const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  questionText: { type: String, required: true },
  options: [{ type: String, required: true }],
  correctAnswerIndex: { type: Number, required: true },
});

const proctoringRulesSchema = new mongoose.Schema({
  maxTabSwitches: { type: Number, default: 3 },
  faceRequired: { type: Boolean, default: true },
  fullscreenRequired: { type: Boolean, default: true },
  maxFaceNotDetected: { type: Number, default: 10 },
});

const examSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String },
  durationMinutes: { type: Number, required: true },
  examCode: { type: String, unique: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  questions: [questionSchema],
  status: { type: String, enum: ['draft', 'published'], default: 'published' },
  proctoringRules: { type: proctoringRulesSchema, default: () => ({}) },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Exam', examSchema);
