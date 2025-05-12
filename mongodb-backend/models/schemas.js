const mongoose = require('mongoose');

// Document Schema for storing files
const documentSchema = new mongoose.Schema({
  file: { type: String, required: true }, // Base64 encoded file
  documentType: { 
    type: String, 
    required: true,
    enum: ['aadhar_card', 'pan_card', 'voter_id', 'candidate_photo', 'voter_photo', 'admin_photo']
  },
  userId: { type: String, required: true },
  fileName: { type: String, required: true },
  uploadedAt: { type: Date, default: Date.now },
  fileSize: { type: Number },
  mimeType: { type: String }
});

// Add indexes for better query performance
documentSchema.index({ userId: 1, documentType: 1 });
documentSchema.index({ uploadedAt: -1 });

// User Schema
const userSchema = new mongoose.Schema({
  userId: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  role: { 
    type: String, 
    enum: ['admin', 'voter', 'candidate'],
    required: true 
  },
  name: { type: String, required: true },
  documents: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Document'
  }],
  isVerified: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

// Add index for userId
userSchema.index({ userId: 1 });

// Election Schema
const electionSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String, required: true },
  startDate: { type: Date, required: true },
  endDate: { type: Date, required: true },
  isActive: { type: Boolean, default: true },
  totalVotes: { type: Number, default: 0 },
  status: { 
    type: String, 
    enum: ['upcoming', 'active', 'completed'],
    default: 'upcoming'
  },
  createdAt: { type: Date, default: Date.now }
});

// Candidate Schema
const candidateSchema = new mongoose.Schema({
  name: { type: String, required: true },
  party: { type: String, required: true },
  manifesto: { type: String, required: true },
  electionId: { 
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Election',
    required: true
  },
  photoUrl: { type: String },
  voteCount: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now }
});

// Vote Schema
const voteSchema = new mongoose.Schema({
  voterId: { 
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  electionId: { 
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Election',
    required: true
  },
  candidateId: { 
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Candidate',
    required: true
  },
  timestamp: { type: Date, default: Date.now },
  isVerified: { type: Boolean, default: false }
});

// Proctoring Video Schema
const proctoringVideoSchema = new mongoose.Schema({
  sessionId: {
    type: String,
    required: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
    index: true
  },
  electionId: {
    type: String,
    required: true,
    index: true
  },
  cameraType: {
    type: String,
    required: true,
    enum: ['front', 'rear']
  },
  fileName: {
    type: String,
    required: true
  },
  fileId: {
    type: mongoose.Schema.Types.ObjectId, // Reference to GridFS file
    required: true,
    index: true
  },
  timestamp: {
    type: Date,
    default: Date.now
  },
  status: {
    type: String,
    required: true,
    enum: ['recording', 'completed', 'failed'],
    default: 'recording'
  }
});

// Face Image Schema
const faceImageSchema = new mongoose.Schema({
  userId: { type: String, required: true },
  faceImage: { type: String, required: true }, // Base64 encoded
  extractedFrom: { type: String, required: true, enum: ['voter_id', 'live'] },
  filePath: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  isVerified: { type: Boolean, default: false }
});

// Add indexes for better query performance
faceImageSchema.index({ userId: 1 });
faceImageSchema.index({ isVerified: 1 });

// Create models
const Document = mongoose.model('Document', documentSchema);
const User = mongoose.model('User', userSchema);
const Election = mongoose.model('Election', electionSchema);
const Candidate = mongoose.model('Candidate', candidateSchema);
const Vote = mongoose.model('Vote', voteSchema);
const ProctoringVideo = mongoose.model('ProctoringVideo', proctoringVideoSchema);
const FaceImage = mongoose.model('FaceImage', faceImageSchema);

module.exports = {
  Document,
  User,
  Election,
  Candidate,
  Vote,
  ProctoringVideo,
  FaceImage
}; 