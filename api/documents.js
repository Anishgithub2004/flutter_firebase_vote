import { Document, User } from '../mongodb-backend/models/schemas';
import mongoose from 'mongoose';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import os from 'os';

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

// Connect to MongoDB
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
}).then(() => {
  console.log('Connected to MongoDB');
}).catch(err => {
  console.error('MongoDB connection error:', err);
});

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  upload.single('file')(req, res, async (err) => {
    if (err) {
      console.error('Multer error:', err);
      return res.status(500).json({ success: false, error: 'File upload error' });
    }

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
} 