"""
PDF Service for server-side processing (Web requests only)
"""
import io
from typing import List, Dict, Any
from datetime import datetime
from PyPDF2 import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4, A3, LETTER
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib import colors

# Paper size mapping
PAPER_SIZES = {
    'A4': A4,
    'A3': A3,
    'LETTER': LETTER,
}

def create_cover_sheet(metadata: Dict[str, Any]) -> bytes:
    """
    Generate a cover sheet PDF with order details.
    Only used for web requests (processing_mode == 'server')
    """
    buffer = io.BytesIO()
    
    # Get paper size from config
    paper_size = metadata.get('config', {}).get('paperSize', 'A4')
    page_size = PAPER_SIZES.get(paper_size, A4)
    
    c = canvas.Canvas(buffer, pagesize=page_size)
    width, height = page_size
    
    # Header
    c.setFillColor(colors.HexColor('#6200EE'))
    c.rect(0, height - 80, width, 80, fill=True, stroke=False)
    
    c.setFillColor(colors.white)
    c.setFont('Helvetica-Bold', 24)
    c.drawCentredString(width / 2, height - 50, 'PRINT ORDER')
    
    # Order ID
    order_id = metadata.get('orderId', 'UNKNOWN')
    c.setFont('Helvetica', 14)
    c.drawCentredString(width / 2, height - 70, f'Order ID: {order_id}')
    
    # Student Details Section
    y_pos = height - 120
    c.setFillColor(colors.black)
    c.setFont('Helvetica-Bold', 16)
    c.drawString(40, y_pos, 'Student Details')
    
    y_pos -= 30
    c.setFont('Helvetica', 12)
    student = metadata.get('student', {})
    details = [
        ('Name', student.get('name', 'N/A')),
        ('Student ID', student.get('studentId', 'N/A')),
        ('Phone', student.get('phone', 'N/A')),
    ]
    
    for label, value in details:
        c.drawString(50, y_pos, f'{label}:')
        c.drawString(150, y_pos, str(value))
        y_pos -= 20
    
    # Print Configuration Section
    y_pos -= 20
    c.setFont('Helvetica-Bold', 16)
    c.drawString(40, y_pos, 'Print Configuration')
    
    y_pos -= 30
    c.setFont('Helvetica', 12)
    config = metadata.get('config', {})
    config_details = [
        ('Paper Size', config.get('paperSize', 'A4')),
        ('Print Type', 'Color' if config.get('printType') == 'COLOR' else 'Black & White'),
        ('Print Side', 'Double-sided' if config.get('printSide') == 'DOUBLE' else 'Single-sided'),
        ('Copies', config.get('copies', 1)),
        ('Total Pages', config.get('totalPages', 0)),
    ]
    
    for label, value in config_details:
        c.drawString(50, y_pos, f'{label}:')
        c.drawString(150, y_pos, str(value))
        y_pos -= 20
    
    # Payment Section
    y_pos -= 20
    c.setFont('Helvetica-Bold', 16)
    c.drawString(40, y_pos, 'Payment Details')
    
    y_pos -= 30
    c.setFont('Helvetica', 12)
    payment = metadata.get('payment', {})
    total_price = config.get('totalPrice', 0)
    c.drawString(50, y_pos, f'Total Amount:')
    c.setFont('Helvetica-Bold', 14)
    c.drawString(150, y_pos, f'₹{total_price:.2f}')
    
    y_pos -= 20
    c.setFont('Helvetica', 12)
    if payment.get('transactionId'):
        c.drawString(50, y_pos, f'Transaction ID:')
        c.drawString(150, y_pos, payment.get('transactionId', 'N/A'))
    
    # Timestamp
    y_pos -= 40
    c.setFont('Helvetica', 10)
    c.setFillColor(colors.gray)
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    c.drawString(50, y_pos, f'Generated: {timestamp}')
    
    # Footer
    c.setFillColor(colors.HexColor('#6200EE'))
    c.rect(0, 0, width, 30, fill=True, stroke=False)
    c.setFillColor(colors.white)
    c.setFont('Helvetica', 10)
    c.drawCentredString(width / 2, 10, 'ABDUL MANNAN MOLLA - Print Service')
    
    c.save()
    buffer.seek(0)
    return buffer.read()


def merge_pdfs(pdf_files: List[bytes], cover_sheet: bytes = None) -> bytes:
    """
    Merge multiple PDF files into one.
    Optionally prepend a cover sheet.
    Only used for web requests (processing_mode == 'server')
    """
    writer = PdfWriter()
    
    # Add cover sheet first if provided
    if cover_sheet:
        cover_reader = PdfReader(io.BytesIO(cover_sheet))
        for page in cover_reader.pages:
            writer.add_page(page)
    
    # Add all document pages
    for pdf_bytes in pdf_files:
        try:
            reader = PdfReader(io.BytesIO(pdf_bytes))
            for page in reader.pages:
                writer.add_page(page)
        except Exception as e:
            # print(f"Error reading PDF: {e}")
            # Skip corrupted PDFs
            continue
    
    # Write merged PDF to buffer
    output = io.BytesIO()
    writer.write(output)
    output.seek(0)
    return output.read()


def get_pdf_page_count(pdf_bytes: bytes) -> int:
    """Get the number of pages in a PDF."""
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        return len(reader.pages)
    except:
        return 0
