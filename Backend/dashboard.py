import gradio as gr

def create_dashboard():
    """
    Create a minimal Gradio wrapper.
    This keeps the Hugging Face Space active without exposing any admin UI.
    
    SECURITY: This page intentionally shows NO:
    - API endpoints
    - Server configuration
    - Order data
    - Authentication details
    """
    with gr.Blocks(title="Print Service", theme=gr.themes.Soft()) as demo:
        gr.Markdown("# 🖨️ Print Service")
        gr.Markdown("---")
        gr.Markdown("### ✅ Service Status: **Online**")
        gr.Markdown("""
        This service is running.
        
        For support, contact the administrator.
        """)
        
    return demo
