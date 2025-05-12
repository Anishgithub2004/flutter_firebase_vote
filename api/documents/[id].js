const mongoose = require('mongoose');

// MongoDB Schema definition
const documentSchema = new mongoose.Schema({
  file: String,
  documentType: String,
  userId: String,
  fileName: String,
  fileSize: Number,
  mimeType: String,
  uploadedAt: Date
});

// Create model
const Document = mongoose.model('Document', documentSchema);

// MongoDB connection handler
const connectDB = async () => {
  try {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGODB_URI, {
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
      });
      console.log('Connected to MongoDB');
    }
  } catch (error) {
    console.error('MongoDB connection error:', error);
    throw error;
  }
};

module.exports = async function handler(req, res) {
  try {
    // Connect to MongoDB
    await connectDB();

    if (req.method !== 'GET') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const document = await Document.findById(req.query.id);
    if (!document) {
      return res.status(404).json({ error: 'Document not found' });
    }

    res.json({
      success: true,
      file: document.file,
      fileName: document.fileName
    });
  } catch (error) {
    console.error('Error fetching document:', error);
    res.status(500).json({ error: 'Failed to fetch document' });
  }
} 