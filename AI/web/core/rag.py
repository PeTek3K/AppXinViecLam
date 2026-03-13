from google import genai  # dùng SDK mới của Google AI


class RAG:
    def __init__(self, api_key, model_name):
        # Khởi tạo client Gemini
        self.client = genai.Client(api_key=api_key)
        self.model_name = model_name

    def generate_answer(self, query, context, cv):
        # Giữ NGUYÊN nội dung prompt như file gốc của bạn
        if not query:
            combined_prompt = f"""
        Bạn là một chuyên gia trong lĩnh vực tuyển dụng, dưới đây là 3 job đã được xem là gần như phù hợp với CV của ứng viên
        Job được đưa ra là:
        {context}
        Dựa vào CV của ứng viên: {cv}, hãy đánh giá xem ứng viên và đưa ra lời khuyên cho ứng viên về việc cần cải thiện CV.
    """
        elif not cv:
            print("Vui lòng nhập CV của ứng viên")
            return None
        else:
            combined_prompt = f"""
        Bạn là một chuyên gia trong lĩnh vực tuyển dụng, dưới đây là 3 job đã được xem là gần như phù hợp với CV của ứng viên
        Dựa vào CV của ứng viên: {cv} và job {context} đã được đưa ra, hãy trả lời câu hỏi: {query}
    """

        # Gọi Gemini giống như trước, chỉ khác là qua client mới
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=combined_prompt
        )
        return response.text
