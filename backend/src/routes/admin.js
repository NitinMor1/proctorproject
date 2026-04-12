const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Exam = require('../models/Exam');
const Submission = require('../models/Submission');
const Session = require('../models/Session');
const Violation = require('../models/Violation');

// GET /api/admin/stats — All dashboard stats in one call
router.get('/stats', async (req, res) => {
  try {
    const [
      totalStudents,
      totalExams,
      totalViolations,
      sessions,
      recentSubmissions,
    ] = await Promise.all([
      User.countDocuments({ role: 'student' }),
      Exam.countDocuments(),
      Violation.countDocuments(),
      Session.find().select('integrityScore status'),
      Submission.find()
        .sort({ submittedAt: -1 })
        .limit(10)
        .populate('student', 'name email')
        .populate('exam', 'title'),
    ]);

    // Calculate average integrity score from all sessions
    const avgIntegrity = sessions.length > 0
      ? Math.round(sessions.reduce((sum, s) => sum + (s.integrityScore || 100), 0) / sessions.length)
      : 100;

    // Integrity distribution from submissions
    const allSubmissions = await Submission.find().select('score maxScore');
    let highRisk = 0, warning = 0, flagged = 0;
    allSubmissions.forEach(s => {
      const pct = s.maxScore > 0 ? (s.score / s.maxScore) * 100 : 100;
      if (pct >= 70) highRisk++;      // "Low Risk" / passed
      else if (pct >= 40) warning++;   // Borderline
      else flagged++;                  // "Flagged" / failed
    });

    res.json({
      totalStudents,
      totalExams,
      totalViolations,
      avgIntegrity,
      integrityDistribution: { lowRisk: highRisk, warning, flagged },
      recentSubmissions: recentSubmissions.map(sub => ({
        _id: sub._id,
        studentName: sub.student?.name || 'Unknown',
        studentEmail: sub.student?.email || '',
        examTitle: sub.exam?.title || 'Unknown Exam',
        score: sub.score,
        maxScore: sub.maxScore,
        submittedAt: sub.submittedAt,
        status: sub.maxScore > 0 && (sub.score / sub.maxScore) >= 0.7 ? 'Clean' : 'Warning',
      })),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/admin/students — All students with details
router.get('/students', async (req, res) => {
  try {
    const students = await User.find({ role: 'student' })
      .select('-password -faceEmbedding')
      .sort({ registeredAt: -1 });

    // For each student, get their submission count
    const enriched = await Promise.all(students.map(async (s) => {
      const submissionCount = await Submission.countDocuments({ student: s._id });
      return {
        _id: s._id,
        name: s.name,
        email: s.email,
        registeredAt: s.registeredAt,
        submissionCount,
      };
    }));

    res.json(enriched);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/admin/violations — All violations with student details
router.get('/violations', async (req, res) => {
  try {
    const violations = await Violation.find()
      .populate('student', 'name email')
      .sort({ timestamp: -1 })
      .limit(100);
    res.json(violations);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
