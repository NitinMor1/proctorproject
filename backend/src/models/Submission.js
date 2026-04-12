const mongoose = require('mongoose');

const answerSchema = new mongoose.Schema({
  questionId: { type: mongoose.Schema.Types.ObjectId, required: true },
  selectedOptionIndex: { type: Number, required: true }
});

const submissionSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  exam: { type: mongoose.Schema.Types.ObjectId, ref: 'Exam', required: true },
  session: { type: mongoose.Schema.Types.ObjectId, ref: 'Session' }, // Optional link to the Proctoring Session
  answers: [answerSchema],
  score: { type: Number, default: 0 },
  maxScore: { type: Number, default: 0 },
  studentFaceImage: { type: String }, // Base64-encoded face capture taken at exam start
  submittedAt: { type: Date, default: Date.now }
});

// A student can only submit a specific exam once
submissionSchema.index({ student: 1, exam: 1 }, { unique: true });

module.exports = mongoose.model('Submission', submissionSchema);
