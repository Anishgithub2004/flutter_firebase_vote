require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { GridFSBucket } = require('mongodb');
const { Document, User, Election, Candidate, Vote, ProctoringVideo, FaceImage } = require('./models/schemas');

const app = express();

// Middleware
app.use(cors({
  origin: '*', // Allow all origins for development
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Test endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Server is running!',
    timestamp: new Date().toISOString(),
    clientIp: req.ip,
    headers: req.headers
  });
});

// MongoDB Connection and GridFS setup
let bucket;
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  serverSelectionTimeoutMS: 30000,
  socketTimeoutMS: 45000,
  connectTimeoutMS: 30000,
  maxPoolSize: 10,
  minPoolSize: 5,
  maxIdleTimeMS: 30000,
  waitQueueTimeoutMS: 30000,
  retryWrites: true,
  w: 'majority'
})
  .then(() => {
    console.log('Connected to MongoDB');
    bucket = new GridFSBucket(mongoose.connection.db, {
      bucketName: 'proctoring_videos'
    });
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
    if (err.name === 'MongooseServerSelectionError') {
      console.error('Please check:');
      console.error('1. Your IP address is whitelisted in MongoDB Atlas');
      console.error('2. The connection string is correct');
      console.error('3. Your network allows connections to MongoDB Atlas');
      console.error('4. Try using a different network (e.g., mobile hotspot)');
    }
  });

// Add connection event listeners
mongoose.connection.on('connected', () => {
  console.log('Mongoose connected to MongoDB');
});

mongoose.connection.on('error', (err) => {
  console.error('Mongoose connection error:', err);
});

mongoose.connection.on('disconnected', () => {
  console.log('Mongoose disconnected from MongoDB');
});

// Handle process termination
process.on('SIGINT', async () => {
  try {
    await mongoose.connection.close();
    console.log('Mongoose connection closed through app termination');
    process.exit(0);
  } catch (err) {
    console.error('Error closing mongoose connection:', err);
    process.exit(1);
  }
});

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(os.tmpdir(), 'proctoring_uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  }
});

const upload = multer({ storage: storage });

// Document Routes
app.post('/api/documents', upload.single('file'), async (req, res) => {
  try {
    const { documentType, userId } = req.body;
    const file = req.file;

    if (!file) {
      console.error('No file uploaded');
      return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    console.log('Processing document upload:', {
      documentType,
      userId,
      fileName: file.originalname,
      fileSize: file.size,
      mimeType: file.mimetype
    });

    // Validate document type
    const validDocumentTypes = ['aadhar_card', 'pan_card', 'voter_id', 'candidate_photo', 'voter_photo', 'admin_photo'];
    if (!validDocumentTypes.includes(documentType)) {
      console.error('Invalid document type:', documentType);
      return res.status(400).json({ success: false, error: 'Invalid document type' });
    }

    // Read file as base64
    const fileData = fs.readFileSync(file.path);
    const base64Data = fileData.toString('base64');

    // Create document in MongoDB
    const document = new Document({
      file: base64Data,
      documentType,
      userId,
      fileName: file.originalname,
      fileSize: file.size,
      mimeType: file.mimetype,
      uploadedAt: new Date()
    });

    await document.save();
    console.log('Document saved successfully:', document._id);

    // Clean up uploaded file
    fs.unlinkSync(file.path);

    try {
      // Find or create user and update documents array
      let user = await User.findOne({ userId: userId });
      
      if (!user) {
        // Create new user if not exists
        user = new User({
          userId: userId,
          email: `${userId}@temp.com`, // Temporary email
          role: 'voter', // Default role
          name: 'Unnamed User', // Default name
          documents: [document._id]
        });
        await user.save();
        console.log('Created new user:', user._id);
      } else {
        // Update existing user's documents array
        user.documents.push(document._id);
        await user.save();
        console.log('Updated user documents:', user._id);
      }
    } catch (userError) {
      console.error('Error updating user:', userError);
      // Continue with the response even if user update fails
    }

    res.status(201).json({
      success: true,
      documentId: document._id,
      documentUrl: `/api/documents/${document._id}`
    });
  } catch (error) {
    console.error('Error uploading document:', error);
    res.status(500).json({ success: false, error: 'Failed to upload document' });
  }
});

app.get('/api/documents/:id', async (req, res) => {
  try {
    const document = await Document.findById(req.params.id);
    if (!document) {
      return res.status(404).json({ error: 'Document not found' });
    }

    res.json({
      success: true,
      file: document.file,
      fileName: document.fileName
    });
  } catch (error) {
    console.error('Error getting document:', error);
    res.status(500).json({ error: 'Failed to get document' });
  }
});

// Get all documents for a specific user
app.get('/api/documents/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('Fetching documents for user:', userId);
    
    const documents = await Document.find({ userId });
    console.log('Found documents:', documents);
    
    res.json(documents);
  } catch (error) {
    console.error('Error fetching user documents:', error);
    res.status(500).json({ error: 'Failed to fetch user documents' });
  }
});

// Check if user has all required KYC documents
app.get('/api/documents/check-kyc/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('Checking KYC documents for user:', userId);
    
    // Find all documents for the user
    const documents = await Document.find({ userId });
    console.log('Found documents:', documents);
    
    // Check for required document types
    const hasAadhar = documents.some(doc => doc.documentType === 'aadhar_card');
    const hasPan = documents.some(doc => doc.documentType === 'pan_card');
    const hasVoterId = documents.some(doc => doc.documentType === 'voter_id');
    
    const hasAllDocuments = hasAadhar && hasPan && hasVoterId;
    
    res.json({
      success: true,
      hasAllDocuments,
      documents: {
        aadhar: hasAadhar,
        pan: hasPan,
        voterId: hasVoterId
      },
      message: hasAllDocuments 
        ? 'All KYC documents are present'
        : 'Missing some KYC documents'
    });
  } catch (error) {
    console.error('Error checking KYC documents:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to check KYC documents',
      details: error.message
    });
  }
});

// Face Image Routes
app.post('/api/face-images/save', upload.single('faceImage'), async (req, res) => {
  try {
    const { userId, extractedFrom } = req.body;
    const filePath = req.file.path;
    
    // Read the image file and convert to base64
    const imageBuffer = fs.readFileSync(filePath);
    const base64Image = imageBuffer.toString('base64');

    const faceImage = new FaceImage({
      userId,
      faceImage: base64Image,
      extractedFrom,
      filePath,
      isVerified: false
    });

    await faceImage.save();
    res.status(201).json({ message: 'Face image saved successfully', faceImage });
  } catch (error) {
    console.error('Error saving face image:', error);
    res.status(500).json({ error: 'Failed to save face image' });
  }
});

app.get('/api/face-images/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const faceImages = await FaceImage.find({ userId });
    res.json(faceImages);
  } catch (error) {
    console.error('Error fetching face images:', error);
    res.status(500).json({ error: 'Failed to fetch face images' });
  }
});

app.patch('/api/face-images/:id/verify', async (req, res) => {
  try {
    const { id } = req.params;
    const { isVerified } = req.body;
    
    const faceImage = await FaceImage.findByIdAndUpdate(
      id,
      { isVerified },
      { new: true }
    );

    if (!faceImage) {
      return res.status(404).json({ error: 'Face image not found' });
    }

    res.json(faceImage);
  } catch (error) {
    console.error('Error updating verification status:', error);
    res.status(500).json({ error: 'Failed to update verification status' });
  }
});

app.delete('/api/face-images/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const faceImage = await FaceImage.findById(id);

    if (!faceImage) {
      return res.status(404).json({ error: 'Face image not found' });
    }

    // Delete the file from the filesystem
    if (fs.existsSync(faceImage.filePath)) {
      fs.unlinkSync(faceImage.filePath);
    }

    await FaceImage.findByIdAndDelete(id);
    res.json({ message: 'Face image deleted successfully' });
  } catch (error) {
    console.error('Error deleting face image:', error);
    res.status(500).json({ error: 'Failed to delete face image' });
  }
});

// User Routes
app.post('/api/users', async (req, res) => {
  try {
    const user = new User(req.body);
    await user.save();
    res.status(201).json(user);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get('/api/users/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate('documents');
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Election Routes
app.post('/api/elections', async (req, res) => {
  try {
    const election = new Election(req.body);
    await election.save();
    res.status(201).json(election);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get('/api/elections', async (req, res) => {
  try {
    const elections = await Election.find();
    res.json(elections);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Candidate Routes
app.post('/api/candidates', async (req, res) => {
  try {
    const candidate = new Candidate(req.body);
    await candidate.save();
    res.status(201).json(candidate);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get('/api/candidates/:electionId', async (req, res) => {
  try {
    const candidates = await Candidate.find({ electionId: req.params.electionId });
    res.json(candidates);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Vote Routes
app.post('/api/votes', async (req, res) => {
  try {
    const vote = new Vote(req.body);
    await vote.save();
    
    // Update candidate vote count
    await Candidate.findByIdAndUpdate(
      vote.candidateId,
      { $inc: { voteCount: 1 } }
    );
    
    // Update election total votes
    await Election.findByIdAndUpdate(
      vote.electionId,
      { $inc: { totalVotes: 1 } }
    );
    
    res.status(201).json(vote);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Proctoring Video Endpoints
app.post('/api/proctoring_videos', upload.single('file'), async (req, res) => {
  try {
    const { sessionId, cameraType, userId, electionId } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    // Create a readable stream from the uploaded file
    const readStream = fs.createReadStream(file.path);

    // Create a unique filename for GridFS
    const filename = `${sessionId}_${cameraType}_${Date.now()}.mp4`;

    // Upload to GridFS
    const uploadStream = bucket.openUploadStream(filename, {
      metadata: {
        sessionId,
        userId,
        electionId,
        cameraType,
        originalName: file.originalname,
        mimeType: file.mimetype,
        uploadDate: new Date()
      }
    });

    // Pipe the file to GridFS
    readStream.pipe(uploadStream);

    // Wait for upload to complete
    await new Promise((resolve, reject) => {
      uploadStream.on('finish', resolve);
      uploadStream.on('error', reject);
    });

    // Create proctoring video document with reference to GridFS file
    const proctoringVideo = new ProctoringVideo({
      sessionId,
      userId,
      electionId,
      cameraType,
      fileName: filename,
      fileId: uploadStream.id, // Store the GridFS file ID
      status: 'completed'
    });

    await proctoringVideo.save();

    // Clean up the temporary file
    fs.unlinkSync(file.path);

    res.status(201).json({
      success: true,
      videoUrl: `/api/proctoring_videos/${sessionId}/${cameraType}`,
      fileId: uploadStream.id
    });
  } catch (error) {
    console.error('Error uploading proctoring video:', error);
    res.status(500).json({ success: false, error: 'Failed to upload video' });
  }
});

app.get('/api/proctoring_videos/:sessionId/:cameraType', async (req, res) => {
  try {
    const { sessionId, cameraType } = req.params;

    // Find the video document
    const video = await ProctoringVideo.findOne({
      sessionId,
      cameraType,
      status: 'completed'
    });

    if (!video) {
      return res.status(404).json({ success: false, error: 'Video not found' });
    }

    // Find the file in GridFS
    const cursor = bucket.find({ _id: video.fileId });
    const files = await cursor.toArray();

    if (!files.length) {
      return res.status(404).json({ success: false, error: 'Video file not found in GridFS' });
    }

    const file = files[0];

    // Set the proper content type
    res.set('Content-Type', file.metadata.mimeType);
    res.set('Content-Disposition', `attachment; filename="${file.metadata.originalName}"`);

    // Stream the file from GridFS to the response
    const downloadStream = bucket.openDownloadStream(file._id);
    downloadStream.pipe(res);
  } catch (error) {
    console.error('Error retrieving proctoring video:', error);
    res.status(500).json({ success: false, error: 'Failed to retrieve video' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ 
    error: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});

// Start server
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0'; // Listen on all interfaces

// Test MongoDB connection before starting server
mongoose.connection.once('open', () => {
  app.listen(PORT, HOST, () => {
    console.log('\nServer is running!');
    console.log('\nAvailable on:');
    
    // Get all network interfaces
    const networkInterfaces = os.networkInterfaces();
    Object.keys(networkInterfaces).forEach((interfaceName) => {
      networkInterfaces[interfaceName]?.forEach((interface) => {
        if (interface.family === 'IPv4' && !interface.internal) {
          console.log(`- ${interfaceName}: http://${interface.address}:${PORT}`);
        }
      });
    });
    
    console.log('\nTo test the API:');
    console.log('1. Use any of the above IP addresses from your computer');
    console.log('2. Make sure your mobile device is on the same network');
  });
}); 