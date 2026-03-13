from google import genai
from google.genai import types
import json
import numpy as np
import uuid
from qdrant_client.http.models import PointStruct
from qdrant_client import QdrantClient, models

INPUT_FILE_PATH = r'/content/scraped_job_data_HN.json'
OUTPUT_EMBEDDINGS_JSON_PATH = '/content/scraped_job_data_HN_embeeding.json'
# GEMINI_API_KEY = "..."
GEMINI_API_KEY = "AIzaSyDILpdxOqizVuJHuIRvezyUd_jplsOMAVY"
QDRANT_COLLECTION_NAME = "job_embeddings"
URL = "https://b74ab07b-c04a-410b-baba-d9d9109aa228.europe-west3-0.gcp.cloud.qdrant.io"
API = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.19VpHa3sPmWQQ1yuwiVMx9jODThfu3lpSYeRGsRIzLA"

try:
    print(f"Loading data from: {INPUT_FILE_PATH}...")
    with open(INPUT_FILE_PATH, 'r', encoding='utf-8') as file:
        data = json.load(file)
    print(f"Successfully loaded {len(data)} items from JSON.")
except:
    print(f"Failed to load data from: {INPUT_FILE_PATH}")
    exit()

import time
import google.generativeai as genai  # For client initialization
from google.generativeai import types

# --- Configuration ---
EMBEDDING_DIMENSION = 716
GEMINI_EMBEDDING_MODEL_NAME = "gemini-embedding-exp-03-07"

MAX_RETRIES = 5
INITIAL_BACKOFF_SECONDS = 2
MAX_BACKOFF_SECONDS = 32
API_CALL_DELAY_SECONDS = 0.5


def get_embedding_with_retry(embedding_model_client, text_content: str, item_identifier: str):
    if not text_content:
        print(f"Info: No text content provided for {item_identifier}. Skipping embedding for this part.")
        return None

    retries = 0
    backoff_time = INITIAL_BACKOFF_SECONDS
    while retries < MAX_RETRIES:
        try:
            response = embedding_model_client.embed_content(
                content=text_content,
                task_type="SEMANTIC_SIMILARITY"
            )

            if hasattr(response, 'embedding') and response.embedding and hasattr(response.embedding, 'values'):
                embedding_list = response.embedding.values
                if isinstance(embedding_list, list) and all(isinstance(val, (int, float)) for val in embedding_list):
                    if len(embedding_list) == EMBEDDING_DIMENSION:
                        return embedding_list
                    else:
                        print(f"Warning: Embedding for {item_identifier} has unexpected dimension {len(embedding_list)} (expected {EMBEDDING_DIMENSION}).")
                        return None

            elif hasattr(response, 'embeddings') and response.embeddings and \
                    isinstance(response.embeddings, list) and len(response.embeddings) > 0 and \
                    hasattr(response.embeddings[0], 'values'):
                print(f"Debug: Using response.embeddings[0].values for {item_identifier}")
                embedding_list = response.embeddings[0].values
                if isinstance(embedding_list, list) and all(isinstance(val, (int, float)) for val in embedding_list):
                    if len(embedding_list) == EMBEDDING_DIMENSION:
                        return embedding_list
                    else:
                        print(f"Warning: Embedding (from list) for {item_identifier} has unexpected dimension {len(embedding_list)} (expected {EMBEDDING_DIMENSION}).")
                        return None
            else:
                print(f"Warning: Unexpected response structure from embed_content for {item_identifier}.")
                return None

        except Exception as e:
            error_str = str(e).upper()
            is_retryable_error = "429" in error_str or \
                                 "RESOURCE_EXHAUSTED" in error_str or \
                                 "RATE_LIMIT" in error_str or \
                                 "USER_PROJECT_DENIED" in error_str or \
                                 "QUOTA" in error_str

            if is_retryable_error:
                if retries < MAX_RETRIES - 1:
                    print(f"Warning: Retryable error for {item_identifier}. Error: {e}. Retrying in {backoff_time}s (Attempt {retries + 1}/{MAX_RETRIES})")
                    time.sleep(backoff_time)
                    backoff_time = min(backoff_time * 2, MAX_BACKOFF_SECONDS)
                else:
                    print(f"Error: Max retries reached for {item_identifier}. Last Error: {e}")
                    return None
                retries += 1
            else:
                if "TASKTYPE" in error_str and "HAS NO ATTRIBUTE" in error_str:
                    print(f"Critical Error: 'TaskType' attribute error for {item_identifier}. Error: {e}.")
                else:
                    print(f"Error: Failed to encode text for {item_identifier}. Non-retryable error: {e}")
                return None

    print(f"Error: All retries failed for {item_identifier}.")
    return None


def embedding_job():
    try:
        class MockEmbeddingResponseValue:
            def __init__(self, values):
                self.values = values

        class MockEmbeddingResponse:
            def __init__(self, values_list):
                self.embedding = MockEmbeddingResponseValue(values_list)

        class MockGenerativeModel:
            def __init__(self, model_name):
                self.model_name = model_name
                self.call_count = 0

            def embed_content(self, content, task_type=None, config=None):
                print(f"[Mock] Embedding call for model '{self.model_name}': '{content[:30]}...' with task_type '{task_type}'")
                self.call_count += 1
                if "error_prone_text" in content and self.call_count % 3 != 0:
                    raise Exception("Mock 429 RESOURCE_EXHAUSTED error")
                if "long_fail_text" in content:
                    raise Exception("Mock 429 RESOURCE_EXHAUSTED error - will fail all retries")

                mock_vector = list(np.random.rand(EMBEDDING_DIMENSION))
                return MockEmbeddingResponse(mock_vector)

        embedding_model_client = MockGenerativeModel(GEMINI_EMBEDDING_MODEL_NAME)
        print(f"Using Mock Embedding Model: {GEMINI_EMBEDDING_MODEL_NAME}")

    except Exception as e:
        print(f"Error initializing Google Generative AI client or model: {e}")
        return

    embeddings_data = []

    for i, item in enumerate(data):
        item_identifier = f"item {i} (URL: {item.get('URL', 'N/A')})"
        title = item.get('Title', '')
        skills_experience = item.get('Skills and Experience', '')
        print(f"\nProcessing {item_identifier}...")

        if not title and not skills_experience:
            print(f"Info: {item_identifier} has no Title or Skills and Experience. Skipping.")
            embeddings_data.append({
                'URL': item.get('URL', ''),
                'Title_embedding': np.zeros(EMBEDDING_DIMENSION).tolist(),
                'Skills_Experience_embedding': np.zeros(EMBEDDING_DIMENSION).tolist(),
                'Original_Title': title,
                'Original_Skills': skills_experience,
                'Processing_Status': 'Skipped - No content'
            })
            continue

        title_vec_list = np.zeros(EMBEDDING_DIMENSION).tolist()
        title_status = "Not Processed"
        if title:
            print(f"Info: Encoding title for {item_identifier}...")
            embedding_list = get_embedding_with_retry(embedding_model_client, title, f"{item_identifier} - Title")
            if embedding_list:
                title_vec_list = embedding_list
                title_status = "Success"
                print(f"Success: Title embedding obtained for {item_identifier}.")
            else:
                title_status = "Failed - Using Zero Vector"
            time.sleep(API_CALL_DELAY_SECONDS)

        skills_experience_vec_list = np.zeros(EMBEDDING_DIMENSION).tolist()
        skills_status = "Not Processed"
        if skills_experience:
            print(f"Info: Encoding skills_experience for {item_identifier}...")
            embedding_list = get_embedding_with_retry(embedding_model_client, skills_experience, f"{item_identifier} - Skills/Exp")
            if embedding_list:
                skills_experience_vec_list = embedding_list
                skills_status = "Success"
                print(f"Success: Skills/Experience embedding obtained for {item_identifier}.")
            else:
                skills_status = "Failed - Using Zero Vector"
            time.sleep(API_CALL_DELAY_SECONDS)

        embedding_item = {
            'URL': item.get('URL', ''),
            'Title_embedding': title_vec_list,
            'Skills_Experience_embedding': skills_experience_vec_list,
            'Original_Title': title,
            'Original_Skills': skills_experience,
            'Title_Embedding_Status': title_status,
            'Skills_Embedding_Status': skills_status
        }
        embeddings_data.append(embedding_item)

    print(f"\n--- Embedding generation complete ---")
    print(f"Total items in input data: {len(data)}")
    print(f"Total items processed into embeddings_data: {len(embeddings_data)}")
    return embeddings_data


embeddings_data = embedding_job()

print("\nĐang kết nối tới Qdrant...")
try:
    client = QdrantClient(url=URL, api_key=API)
    try:
        collection_info = client.get_collection(collection_name=QDRANT_COLLECTION_NAME)
        print(f"Collection '{QDRANT_COLLECTION_NAME}' đã tồn tại.")
    except Exception:
        print(f"Collection '{QDRANT_COLLECTION_NAME}' không tìm thấy. Đang tạo collection...")
        client.recreate_collection(
            collection_name=QDRANT_COLLECTION_NAME,
            vectors_config={
                "title": models.VectorParams(size=EMBEDDING_DIMENSION, distance=models.Distance.COSINE),
                "skills_experience": models.VectorParams(size=EMBEDDING_DIMENSION, distance=models.Distance.COSINE),
            }
        )
        print(f"Collection '{QDRANT_COLLECTION_NAME}' đã được tạo thành công.")

    points_to_upsert = []
    for i, item_data in enumerate(embeddings_data):
        if 'error' in item_data:
            print(f"Bỏ qua mục có URL {item_data['URL']} do lỗi trước đó: {item_data['error']}")
            continue

        point_id = str(uuid.uuid4())

        title_emb = item_data['Title_embedding']
        skills_emb = item_data['Skills_Experience_embedding']

        vectors_dict = {}
        if isinstance(title_emb, list) and all(isinstance(x, (int, float)) for x in title_emb) and len(title_emb) == EMBEDDING_DIMENSION:
            vectors_dict["title"] = title_emb
        else:
            print(f"Cảnh báo: Embedding tiêu đề cho URL {item_data['URL']} không hợp lệ hoặc sai kích thước.")

        if isinstance(skills_emb, list) and all(isinstance(x, (int, float)) for x in skills_emb) and len(skills_emb) == EMBEDDING_DIMENSION:
            vectors_dict["skills_experience"] = skills_emb
        else:
            print(f"Cảnh báo: Embedding kỹ năng/kinh nghiệm cho URL {item_data['URL']} không hợp lệ hoặc sai kích thước.")

        if not vectors_dict:
            print(f"Bỏ qua điểm cho URL {item_data['URL']} vì không có vector hợp lệ nào được chuẩn bị.")
            continue

        points_to_upsert.append(
            PointStruct(
                id=point_id,
                payload={
                    "URL": item_data['URL'],
                    "Original_Title": item_data.get('Original_Title', ''),
                    "Original_Skills": item_data.get('Original_Skills', '')
                },
                vector=vectors_dict
            )
        )

    if points_to_upsert:
        print(f"Đang tải lên {len(points_to_upsert)} điểm vào collection '{QDRANT_COLLECTION_NAME}' của Qdrant...")

        batch_size = 100
        total_batches = (len(points_to_upsert) + batch_size - 1) // batch_size
        for i in range(0, len(points_to_upsert), batch_size):
            batch = points_to_upsert[i:i + batch_size]
            client.upsert(collection_name=QDRANT_COLLECTION_NAME, points=batch, wait=True)
            print(f"Đã tải lên lô {i // batch_size + 1}/{total_batches}")

        print("Tất cả các điểm đã được tải lên Qdrant thành công.")
    else:
        print("Không có điểm hợp lệ nào được chuẩn bị để tải lên Qdrant.")

except Exception as e:
    print(f"Đã xảy ra lỗi trong quá trình thao tác với Qdrant: {e}")
    print("Vui lòng đảm bảo máy chủ Qdrant đang chạy và có thể truy cập, và thư viện client đã được cài đặt.")

print("\nTập lệnh đã hoàn tất.")
