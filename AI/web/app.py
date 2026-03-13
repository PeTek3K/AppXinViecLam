import os
from flask import Flask, request, jsonify, render_template, session
from werkzeug.utils import secure_filename
from flask_session import Session

# Assuming your core modules are in a 'core' directory sibling to app.py
from core.data import PDFProcessor
from core.embedding_que import EmbeddingQuery
from core.retriever import JobRetriever
from core.rag import RAG

app = Flask(__name__)

# Flask-Session config
app.secret_key = "8f14e45fceea167a5a36dedd4bea2543"
app.config['SESSION_TYPE'] = 'filesystem'
Session(app)

# Upload folder setup
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Constants and API keys
# API_KEY = "AIzaSyBmEEZgpWXv4xe_dRwmJY4bKi9DvO1dQ28"
API_KEY = "AIzaSyBZGFaNHg9tvW80Pate7Mt-vfEXvTG1jhA"
EMBEDDING_MODEL_NAME = "gemini-embedding-exp-03-07"
GENERATION_MODEL_NAME = "gemini-2.5-flash-lite"
EMBEDDING_DIMENSION = 716
QDRANT_URL = "https://b74ab07b-c04a-410b-baba-d9d9109aa228.europe-west3-0.gcp.cloud.qdrant.io"
QDRANT_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.19VpHa3sPmWQQ1yuwiVMx9jODThfu3lpSYeRGsRIzLA"
COLLECTION_NAME = "job_embeddings_nor1"

embedding = EmbeddingQuery(
    api_key=API_KEY,
    model_name=EMBEDDING_MODEL_NAME,
    embedding_dimension=EMBEDDING_DIMENSION,
)

retriever_instance = JobRetriever(
    url=QDRANT_URL,
    api=QDRANT_API_KEY,
    collection_name=COLLECTION_NAME,
    embedding_dimension=EMBEDDING_DIMENSION,
)

rag = RAG(
    api_key=API_KEY,
    model_name=GENERATION_MODEL_NAME,
)

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/upload', methods=['POST'])
def upload_file():
    question_users = request.form.get('question_users', '')
    files = request.files.getlist('files')
    use_previous = request.form.get('use_previous_file') == 'true'

    pdf_info = None
    text_content_from_pdf = ""
    uploaded_filepath = None

    try:
        if files:
            pdf_file = None
            for f in files:
                if f.filename and f.filename.lower().endswith('.pdf'):
                    pdf_file = f
                    break

            if not pdf_file:
                return jsonify({"error": "Không tìm thấy file PDF hợp lệ trong các file đã tải lên."}), 400

            filename = secure_filename(pdf_file.filename)
            uploaded_filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            pdf_file.save(uploaded_filepath)
            print(f"PDF saved to: {uploaded_filepath}")
            session['uploaded_filepath'] = uploaded_filepath

            pdf_processor = PDFProcessor(uploaded_filepath)
            pdf_processor.read_pdf()
            text_content_from_pdf = pdf_processor.get_text_content()

            pdf_info = {
                "filename": filename,
                "size": os.path.getsize(uploaded_filepath),
                "path": uploaded_filepath
            }

            # Lưu đường dẫn file vào session
            session['uploaded_filepath'] = uploaded_filepath

        elif use_previous:
            prev_path = session.get('uploaded_filepath')
            if prev_path and os.path.exists(prev_path):
                filename = os.path.basename(prev_path)
                pdf_info = {
                    "filename": filename,
                    "size": os.path.getsize(prev_path),
                    "path": prev_path
                }

                pdf_processor = PDFProcessor(prev_path)
                pdf_processor.read_pdf()
                text_content_from_pdf = pdf_processor.get_text_content()
            else:
                return jsonify({"error": "Không có file đã gửi trước để sử dụng."}), 400

        elif not question_users:
            return jsonify({"error": "Vui lòng nhập câu hỏi hoặc tải lên một file."}), 400

        # Quyết định nội dung để tạo embedding
        if text_content_from_pdf:
            embedding_text = text_content_from_pdf
        else:
            embedding_text = question_users

        if not embedding_text:
            return jsonify({"error": "Không có nội dung để tạo embedding. Vui lòng nhập câu hỏi hoặc tải lên CV."}), 400

        question_embedding = embedding.embed_text(embedding_text)
        similar_jobs = retriever_instance.retrieve_jobs(question_embedding, limit=5)
        answer = rag.generate_answer(question_users, similar_jobs, text_content_from_pdf)

        return jsonify({
            "status": "success",
            "question": question_users,
            "answer": answer,
            "received_data": {
                "user_question": question_users,
                "pdf_content": text_content_from_pdf,
                "pdf_info": pdf_info
            }
        }), 200

    except Exception as e:
        print(f"Error during processing: {e}")
        return jsonify({"error": f"Lỗi khi xử lý câu hỏi hoặc file: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(debug=True)
