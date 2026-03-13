from pdfminer.high_level import extract_text

class PDFProcessor:
    def __init__(self, pdf_path, text_content=None, user_question=None):
        self.pdf_path = pdf_path
        self.text_content = text_content
        self.user_question = user_question

    def read_pdf(self):
        try:
            self.text_pdf = extract_text(self.pdf_path)
            return True
        except FileNotFoundError:
            print(f"Lỗi: Không tìm thấy file tại đường dẫn: {self.pdf_path}")
            return False
        except Exception as e:
            print(f"Đã xảy ra lỗi khi đọc file PDF: {e}")
            return False
    
    def get_text_content(self):
        return self.text_pdf
    
    def get_user_question(self):
        return self.user_question


