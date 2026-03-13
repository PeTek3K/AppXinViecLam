import os
from flask import Flask, request, jsonify, render_template
from werkzeug.utils import secure_filename
import tempfile

# Assuming your core modules are in a 'core' directory sibling to app.py
# You'll need to ensure these modules (PDFProcessor, EmbeddingQuery, JobRetriever, RAG)
# are correctly defined and accessible in your project structure.
# For this example, I'll assume they exist and are importable.
# Placeholder classes if core modules are not available for dry run:
class PDFProcessor:
    def __init__(self, pdf_path):
        self.pdf_path = pdf_path
        self.text_content = ""
        print(f"PDFProcessor initialized with {pdf_path}")

    def read_pdf(self):
        # Placeholder: In a real scenario, this would read PDF.
        # For now, let's simulate extracting some text if it's a known test file,
        # or just return dummy text.
        if self.pdf_path and "sample.pdf" in self.pdf_path: # Example condition
            self.text_content = "This is sample text from the PDF about software engineering."
        else:
            self.text_content = "Simulated PDF content."
        print(f"PDF read, content: '{self.text_content[:50]}...'")
        return self.text_content # Return for chaining or direct use

    def get_text_content(self):
        # Returns previously read text or reads if not already done.
        if not self.text_content and self.pdf_path:
            self.read_pdf()
        return self.text_content

class EmbeddingQuery:
    def __init__(self, api_key, model_name, embedding_dimension):
        self.api_key = api_key
        self.model_name = model_name
        self.embedding_dimension = embedding_dimension
        print(f"EmbeddingQuery initialized with model {model_name}")

    def embed_text(self, text):
        # Placeholder: Simulates text embedding
        if not text:
            print("EmbeddingQuery: embed_text called with empty or None text.")
            return None # Or raise error, depending on desired behavior for empty text
        print(f"Embedding text: '{text[:50]}...'")
        return [0.1] * self.embedding_dimension # Simulated embedding vector

class JobRetriever:
    def __init__(self, url, api, collection_name, embedding_dimension):
        self.url = url
        self.api = api
        self.collection_name = collection_name
        self.embedding_dimension = embedding_dimension
        print(f"JobRetriever initialized for collection {collection_name}")

    def retrieve_jobs(self, embedding_vector):
        # Placeholder: Simulates job retrieval
        if embedding_vector is None:
            print("JobRetriever: retrieve_jobs called with None embedding_vector. Returning empty list.")
            return []
        print(f"Retrieving jobs with embedding vector (first 5 dims): {embedding_vector[:5]}")
        # Simulate finding some jobs
        return [
            {"id": "job1", "title": "Software Engineer", "score": 0.9, "description": "Develop amazing software."},
            {"id": "job2", "title": "Data Scientist", "score": 0.85, "description": "Analyze interesting data."}
        ]

class RAG:
    def __init__(self, api_key, model_name):
        self.api_key = api_key
        self.model_name = model_name
        print(f"RAG initialized with model {model_name}")

    def generate_answer(self, question, context_jobs, cv_text):
        # Placeholder: Simulates RAG answer generation
        print(f"Generating answer for question: '{question}'")
        print(f"Context jobs count: {len(context_jobs)}")
        print(f"CV text provided: {'Yes' if cv_text else 'No'}")
        
        answer_parts = [f"Based on your question: '{question}'"]
        if cv_text:
            answer_parts.append(f"and your CV content (first 50 chars): '{cv_text[:50]}...'")
        if context_jobs:
            answer_parts.append("we found the following relevant job(s):")
            for job in context_jobs[:2]: # Show details for a couple of jobs
                answer_parts.append(f"- {job.get('title', 'N/A')} (Score: {job.get('score', 'N/A')})")
        else:
            answer_parts.append("No specific jobs were retrieved based on the CV provided, or no CV was provided.")
        
        answer_parts.append("This is a generated answer using the RAG model.")
        return "\n".join(answer_parts)

# --- End of Placeholder Classes ---

# Actual core module imports (uncomment if you have them)
# from core.data import PDFProcessor
# from core.embedding_que import EmbeddingQuery
# from core.retriever import JobRetriever
# from core.rag import RAG

app = Flask(__name__)

# Configuration
API_KEY = os.getenv("GOOGLE_API_KEY", "YOUR_DEFAULT_API_KEY_IF_NOT_SET") # Use environment variable
EMBEDDING_MODEL_NAME = "gemini-embedding-exp-03-07" # Ensure this is a valid model name for your EmbeddingQuery class
GENERATION_MODEL_NAME = "gemini-2.0-flash" # Ensure this is valid for your RAG class
EMBEDDING_DIMENSION = 768 # Common dimension for many models, adjust if yours is different. Original 716716 seems very high.
QDRANT_URL = os.getenv("QDRANT_URL", "YOUR_QDRANT_URL")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "YOUR_QDRANT_API_KEY")
COLLECTION_NAME = "job_embeddings_nor1"

# Initialize core components
# These initializations should use the actual classes from your 'core' module
# For demonstration, they use the placeholder classes defined above if 'core' modules are not found.
try:
    from core.data import PDFProcessor as CorePDFProcessor
    from core.embedding_que import EmbeddingQuery as CoreEmbeddingQuery
    from core.retriever import JobRetriever as CoreJobRetriever
    from core.rag import RAG as CoreRAG

    pdf_processor_cls = CorePDFProcessor
    embedding_query_cls = CoreEmbeddingQuery
    job_retriever_cls = CoreJobRetriever
    rag_cls = CoreRAG
    print("Using actual core modules.")

except ImportError:
    print("Core modules not found, using placeholder classes for demonstration.")
    pdf_processor_cls = PDFProcessor
    embedding_query_cls = EmbeddingQuery
    job_retriever_cls = JobRetriever
    rag_cls = RAG


embedding_query_instance = embedding_query_cls(
    api_key=API_KEY,
    model_name=EMBEDDING_MODEL_NAME,
    embedding_dimension=EMBEDDING_DIMENSION
)

retriever_instance = job_retriever_cls(
    url=QDRANT_URL,
    api=QDRANT_API_KEY,
    collection_name=COLLECTION_NAME,
    embedding_dimension=EMBEDDING_DIMENSION # Pass dimension here if your retriever needs it
)

rag_instance = rag_cls(
    api_key=API_KEY,
    model_name=GENERATION_MODEL_NAME
)

# Route to serve the HTML file
@app.route('/')
def index():
    # Ensure you have an 'index.html' in a 'templates' folder
    # relative to where app.py is run.
    return render_template('index.html')

# API endpoint to handle questions and file uploads
@app.route('/ask', methods=['POST'])
def ask_question():
    user_question = request.form.get('question')
    pdf_file = request.files.get('pdf_file')

    if not user_question:
        return jsonify({"error": "Vui lòng nhập câu hỏi của bạn."}), 400

    pdf_path = None
    pdf_info = None
    text_content_from_pdf = ""

    # Handle PDF file upload
    if pdf_file and pdf_file.filename: # Check if a file was actually selected
        try:
            # Use a temporary directory for secure file handling
            with tempfile.TemporaryDirectory() as temp_dir:
                filename = secure_filename(pdf_file.filename)
                pdf_path = os.path.join(temp_dir, filename)
                pdf_file.save(pdf_path)
                
                # Use the appropriate PDFProcessor class
                processor_instance = pdf_processor_cls(pdf_path)
                # The read_pdf method in the placeholder now extracts text and stores it.
                # Assuming your actual PDFProcessor might work similarly or you call a method to get text.
                processor_instance.read_pdf() 
                text_content_from_pdf = processor_instance.get_text_content()
                
                pdf_info = {
                    "filename": filename, # Use secured filename
                    "size": os.path.getsize(pdf_path) 
                }
        except Exception as e:
            # No need to manually remove pdf_path if using TemporaryDirectory, it handles cleanup.
            print(f"Error processing PDF: {e}")
            return jsonify({"error": f"Lỗi khi xử lý file PDF: {str(e)}"}), 500
        # temp_dir and its contents (pdf_path) are automatically cleaned up here
    
    uploaded_data = {
        "user_question": user_question, # Clarified that this is the user's question
        "pdf_info": pdf_info,
        # Optionally include extracted PDF text for transparency, if desired
        # "pdf_text_content_preview": text_content_from_pdf[:200] if text_content_from_pdf else "No PDF content processed."
    }

    # --- Core Logic ---
    try:
        # Embedding user question (if needed for other purposes, not directly used for results_cv here)
        # query_embedding_user = embedding_query_instance.embed_text(user_question)

        query_embedding_cv = None
        if text_content_from_pdf:
            try:
                query_embedding_cv = embedding_query_instance.embed_text(text_content_from_pdf)
            except Exception as e:
                print(f"Error embedding PDF content: {e}")
                # query_embedding_cv remains None, job retrieval based on CV will be skipped or use default

        # Initialize results_cv. This ensures it's always defined for the response.
        results_cv = [] 
        
        if query_embedding_cv is not None:
            try:
                results_cv = retriever_instance.retrieve_jobs(query_embedding_cv)
            except Exception as e:
                print(f"Lỗi khi trích xuất dữ liệu từ Qdrant dựa trên CV: {e}")
                # results_cv remains [], or you could set it to an error message:
                # results_cv = {"error": "Không thể truy xuất công việc phù hợp từ CV."}
                pass # Allow RAG to proceed, possibly with no job context from CV
        else:
            # No CV content was processed, or embedding failed.
            # results_cv is already [], which is appropriate.
            # Optionally, provide a specific message if the frontend needs to distinguish this state:
            # results_cv = {"message": "Không có nội dung CV để tìm kiếm công việc."}
            print("No CV embedding available for job retrieval.")


        # Generate answer using RAG
        # The RAG instance receives results_cv (which could be an empty list or actual job data)
        # and the original text_content_from_pdf.
        answer = rag_instance.generate_answer(user_question, results_cv, text_content_from_pdf)
        
        return jsonify({
            "results_cv": results_cv,   # results_cv is always included in the response
            "answer": answer,
            "uploaded_data": uploaded_data, # Contains info about the user's question and PDF
            "message": "Yêu cầu đã được xử lý thành công."
        }), 200

    except Exception as e:
        # This catches errors from embedding (if any unhandled), RAG process, or other logic
        print(f"Lỗi trong quá trình xử lý chính (embedding/RAG): {e}")
        return jsonify({"error": f"Đã xảy ra lỗi trong quá trình xử lý: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)