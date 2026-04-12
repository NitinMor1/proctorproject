const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  questionText: { type: String, required: true },
  options: [{ type: String, required: true }], // Array of 4 strings usually
  correctAnswerIndex: { type: Number, required: true }, // 0, 1, 2, or 3
});

const examSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String },
  durationMinutes: { type: Number, required: true },
  examCode: { type: String, unique: true }, // Auto-generated code for students to enter
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Admin who created it
  questions: [questionSchema],
  status: { type: String, enum: ['draft', 'published'], default: 'published' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Exam', examSchema);
