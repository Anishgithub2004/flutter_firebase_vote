from pymongo import MongoClient
import gridfs
from bson import ObjectId

def check_voter_documents():
    try:
        # Connect to MongoDB Atlas
        connection_string = "mongodb+srv://anish444:e-votex@e-votex.nlfozfk.mongodb.net/E-voting?retryWrites=true&w=majority"
        client = MongoClient(connection_string)
        db = client['E-voting']
        fs = gridfs.GridFS(db)
        
        # Get all documents from the documents collection
        documents = list(db.documents.find())
        
        if not documents:
            print("No documents found in the database.")
            return
        
        print(f"Found {len(documents)} documents:")
        print("-" * 50)
        
        for doc in documents:
            print(f"Document ID: {doc.get('_id', 'N/A')}")
            print(f"User ID: {doc.get('userId', 'N/A')}")
            print(f"Document Type: {doc.get('documentType', 'N/A')}")
            
            if 'fileId' in doc:
                print("File ID: Present")
                try:
                    # Try to get the document from GridFS
                    file_doc = fs.get(ObjectId(doc['fileId']))
                    print(f"Document size: {file_doc.length} bytes")
                except Exception as e:
                    print(f"Error accessing document: {e}")
            else:
                print("File ID: Not found")
            
            print("-" * 50)
        
    except Exception as e:
        print(f"Error connecting to MongoDB: {e}")

if __name__ == "__main__":
    check_voter_documents() 