const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Read the data structure
const dataStructure = JSON.parse(fs.readFileSync('./firebase_data_structure.json', 'utf8'));

async function initializeCollections() {
  try {
    // Create collections
    for (const [collectionName, collectionData] of Object.entries(dataStructure.collections)) {
      console.log(`Creating collection: ${collectionName}`);
      
      // Create a sample document to ensure the collection exists
      const sampleDoc = {};
      for (const [field, type] of Object.entries(collectionData.fields)) {
        switch (type) {
          case 'string':
            sampleDoc[field] = '';
            break;
          case 'number':
            sampleDoc[field] = 0;
            break;
          case 'boolean':
            sampleDoc[field] = false;
            break;
          case 'timestamp':
            sampleDoc[field] = admin.firestore.FieldValue.serverTimestamp();
            break;
          case 'map':
            sampleDoc[field] = {};
            break;
        }
      }

      // Add the sample document
      await db.collection(collectionName).add(sampleDoc);
      console.log(`Collection ${collectionName} created successfully`);
    }

    console.log('All collections initialized successfully');
  } catch (error) {
    console.error('Error initializing collections:', error);
  } finally {
    // Clean up
    admin.app().delete();
  }
}

initializeCollections(); 