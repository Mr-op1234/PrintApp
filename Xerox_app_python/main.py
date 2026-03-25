"""Main Tkinter UI for Xerox Manager - Dark Mode Edition"""
import tkinter as tk
from tkinter import ttk, messagebox
import os
import threading
from datetime import datetime
from typing import List, Optional

from config import load_config, verify_password
from models import PrintOrder
from database import init_db, save_order, get_pending_orders, get_completed_orders, update_order_status, delete_order
from websocket_client import WebSocketClient
from api_service import send_complete_notification, send_rejection_notification, toggle_service_pause, get_service_status

# Dark Mode Colors
COLORS = {
    "bg": "#1e1e1e",
    "bg_secondary": "#252526",
    "bg_tertiary": "#2d2d30",
    "fg": "#d4d4d4",
    "fg_dim": "#808080",
    "accent": "#0078d4",
    "success": "#4ec9b0",
    "warning": "#dcdcaa",
    "error": "#f14c4c",
    "border": "#3c3c3c",
}


class LoginScreen:
    """Password login screen - Dark Mode"""
    def __init__(self):
        self.authenticated = False
        
        self.root = tk.Tk()
        self.root.title("Xerox Manager - Login")
        self.root.geometry("350x180")
        self.root.resizable(False, False)
        self.root.configure(bg=COLORS["bg"])
        
        self.root.eval('tk::PlaceWindow . center')
        
        frame = tk.Frame(self.root, padx=30, pady=20, bg=COLORS["bg"])
        frame.pack(expand=True, fill=tk.BOTH)
        
        tk.Label(frame, text="🖨️ Xerox Manager", font=("Segoe UI", 16, "bold"),
                 bg=COLORS["bg"], fg=COLORS["fg"]).pack(pady=(0, 20))
        
        pwd_frame = tk.Frame(frame, bg=COLORS["bg"])
        pwd_frame.pack(fill=tk.X)
        
        tk.Label(pwd_frame, text="Password:", font=("Segoe UI", 10),
                 bg=COLORS["bg"], fg=COLORS["fg"]).pack(side=tk.LEFT)
        self.password_entry = tk.Entry(pwd_frame, show="*", width=25, font=("Segoe UI", 10),
                                        bg=COLORS["bg_secondary"], fg=COLORS["fg"],
                                        insertbackground=COLORS["fg"])
        self.password_entry.pack(side=tk.LEFT, padx=(10, 0))
        self.password_entry.bind("<Return>", lambda e: self._login())
        self.password_entry.focus()
        
        tk.Button(frame, text="Login", command=self._login, width=15,
                  font=("Segoe UI", 10), bg=COLORS["accent"], fg="white",
                  activebackground="#005a9e").pack(pady=20)
        
        self.failed_attempts = 0
        
    def _login(self):
        password = self.password_entry.get()
        
        if verify_password(password):
            self.authenticated = True
            self.root.destroy()
        else:
            self.failed_attempts += 1
            self.password_entry.delete(0, tk.END)
            
            if self.failed_attempts >= 5:
                messagebox.showerror("Locked", "Too many failed attempts. Application will close.")
                self.root.destroy()
            else:
                remaining = 5 - self.failed_attempts
                messagebox.showerror("Error", f"Incorrect password.\n{remaining} attempts remaining.")
    
    def run(self) -> bool:
        self.root.mainloop()
        return self.authenticated


class XeroxManagerApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Xerox Manager")
        self.root.geometry("950x600")
        self.root.minsize(850, 500)
        self.root.configure(bg=COLORS["bg"])
        
        self.config = load_config()
        self.pending_orders: List[PrintOrder] = []
        self.completed_orders: List[PrintOrder] = []
        self.ws_client: Optional[WebSocketClient] = None
        self.is_paused = False
        
        self._setup_styles()
        init_db()
        self._build_ui()
        self._load_orders()
        
        if self.config.get("ws_url") and self.config.get("api_token"):
            self.root.after(500, self._connect)
            self.root.after(1000, self._check_pause_status)
    
    def _setup_styles(self):
        """Configure ttk styles for dark mode"""
        style = ttk.Style()
        style.theme_use("clam")
        
        style.configure(".", background=COLORS["bg"], foreground=COLORS["fg"])
        style.configure("TNotebook", background=COLORS["bg"], borderwidth=0)
        style.configure("TNotebook.Tab", background=COLORS["bg_secondary"], 
                        foreground=COLORS["fg"], padding=[12, 6])
        style.map("TNotebook.Tab", background=[("selected", COLORS["accent"])],
                  foreground=[("selected", "white")])
        
        style.configure("Treeview", background=COLORS["bg_secondary"],
                        foreground=COLORS["fg"], fieldbackground=COLORS["bg_secondary"],
                        borderwidth=0, rowheight=28)
        style.configure("Treeview.Heading", background=COLORS["bg_tertiary"],
                        foreground=COLORS["fg"], font=("Segoe UI", 9, "bold"))
        style.map("Treeview", background=[("selected", COLORS["accent"])],
                  foreground=[("selected", "white")])
        
        style.configure("TScrollbar", background=COLORS["bg_tertiary"],
                        troughcolor=COLORS["bg_secondary"])
    
    def _build_ui(self):
        """Build the main UI"""
        top_frame = tk.Frame(self.root, pady=8, padx=10, bg=COLORS["bg"])
        top_frame.pack(fill=tk.X)
        
        self.status_label = tk.Label(top_frame, text="● Disconnected", fg=COLORS["error"],
                                      font=("Segoe UI", 10, "bold"), bg=COLORS["bg"])
        self.status_label.pack(side=tk.LEFT)
        
        self.connect_btn = tk.Button(top_frame, text="Connect", command=self._connect, width=10,
                                      bg=COLORS["bg_tertiary"], fg=COLORS["fg"],
                                      activebackground=COLORS["accent"])
        self.connect_btn.pack(side=tk.LEFT, padx=(20, 5))
        
        self.disconnect_btn = tk.Button(top_frame, text="Disconnect", command=self._disconnect,
                                         width=10, state=tk.DISABLED,
                                         bg=COLORS["bg_tertiary"], fg=COLORS["fg"])
        self.disconnect_btn.pack(side=tk.LEFT, padx=5)
        
        # Pause/Resume Button
        self.pause_btn = tk.Button(top_frame, text="⏸ Pause", command=self._toggle_pause,
                                    width=10, bg=COLORS["bg_tertiary"], fg=COLORS["fg"])
        self.pause_btn.pack(side=tk.LEFT, padx=5)
        
        tk.Button(top_frame, text="Refresh", command=self._load_orders, width=10,
                  bg=COLORS["bg_tertiary"], fg=COLORS["fg"]).pack(side=tk.LEFT, padx=5)
        
        self.count_label = tk.Label(top_frame, text="Pending: 0", font=("Segoe UI", 10),
                                     bg=COLORS["bg"], fg=COLORS["fg"])
        self.count_label.pack(side=tk.RIGHT)
        
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        pending_frame = tk.Frame(self.notebook, bg=COLORS["bg"])
        self.notebook.add(pending_frame, text="  Pending Orders  ")
        self._build_pending_tab(pending_frame)
        
        completed_frame = tk.Frame(self.notebook, bg=COLORS["bg"])
        self.notebook.add(completed_frame, text="  Completed Orders  ")
        self._build_completed_tab(completed_frame)
    
    def _build_pending_tab(self, parent):
        """Build pending orders tab with Transaction ID column"""
        columns = ("pos", "order_id", "student", "phone", "pages", "type", "cost", "txn_id", "time")
        self.pending_tree = ttk.Treeview(parent, columns=columns, show="headings", selectmode="browse")
        
        self.pending_tree.heading("pos", text="#")
        self.pending_tree.heading("order_id", text="Order ID")
        self.pending_tree.heading("student", text="Student")
        self.pending_tree.heading("phone", text="Phone")
        self.pending_tree.heading("pages", text="Pages")
        self.pending_tree.heading("type", text="Type")
        self.pending_tree.heading("cost", text="Cost")
        self.pending_tree.heading("txn_id", text="Txn ID")
        self.pending_tree.heading("time", text="Received")
        
        self.pending_tree.column("pos", width=35, anchor="center")
        self.pending_tree.column("order_id", width=100)
        self.pending_tree.column("student", width=120)
        self.pending_tree.column("phone", width=100)
        self.pending_tree.column("pages", width=50, anchor="center")
        self.pending_tree.column("type", width=70, anchor="center")
        self.pending_tree.column("cost", width=60, anchor="center")
        self.pending_tree.column("txn_id", width=110)
        self.pending_tree.column("time", width=70)
        
        scrollbar = ttk.Scrollbar(parent, orient=tk.VERTICAL, command=self.pending_tree.yview)
        self.pending_tree.configure(yscrollcommand=scrollbar.set)
        
        self.pending_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        btn_frame = tk.Frame(parent, bg=COLORS["bg"])
        btn_frame.pack(side=tk.BOTTOM, fill=tk.X, pady=8)
        
        self.open_btn = tk.Button(btn_frame, text="📂 Open PDF", command=self._open_pdf, width=12,
                                   bg=COLORS["bg_tertiary"], fg=COLORS["fg"])
        self.open_btn.pack(side=tk.LEFT, padx=5)
        
        self.screenshot_btn = tk.Button(btn_frame, text="📷 Screenshot", command=self._view_screenshot, width=12,
                                   bg=COLORS["warning"], fg="#1e1e1e")
        self.screenshot_btn.pack(side=tk.LEFT, padx=5)
        
        self.print_btn = tk.Button(btn_frame, text="🖨️ Print", command=self._print_order, width=12,
                                    bg=COLORS["bg_tertiary"], fg=COLORS["fg"])
        self.print_btn.pack(side=tk.LEFT, padx=5)
        
        self.complete_btn = tk.Button(btn_frame, text="✓ Complete", command=self._complete_order,
                                       width=12, bg=COLORS["success"], fg="#1e1e1e")
        self.complete_btn.pack(side=tk.LEFT, padx=5)
        
        self.delete_btn = tk.Button(btn_frame, text="✗ Delete", command=self._delete_order,
                                     width=12, bg=COLORS["error"], fg="white")
        self.delete_btn.pack(side=tk.RIGHT, padx=5)
        
        self.pending_tree.bind("<<TreeviewSelect>>", self._on_select)
        self.pending_tree.bind("<Double-1>", lambda e: self._open_pdf())
    
    def _build_completed_tab(self, parent):
        """Build completed orders tab with Transaction ID"""
        columns = ("order_id", "student", "pages", "cost", "txn_id", "completed")
        self.completed_tree = ttk.Treeview(parent, columns=columns, show="headings", selectmode="browse")
        
        self.completed_tree.heading("order_id", text="Order ID")
        self.completed_tree.heading("student", text="Student")
        self.completed_tree.heading("pages", text="Pages")
        self.completed_tree.heading("cost", text="Cost")
        self.completed_tree.heading("txn_id", text="Transaction ID")
        self.completed_tree.heading("completed", text="Completed At")
        
        self.completed_tree.column("order_id", width=120)
        self.completed_tree.column("student", width=180)
        self.completed_tree.column("pages", width=70, anchor="center")
        self.completed_tree.column("cost", width=80, anchor="center")
        self.completed_tree.column("txn_id", width=140)
        self.completed_tree.column("completed", width=140)
        
        scrollbar = ttk.Scrollbar(parent, orient=tk.VERTICAL, command=self.completed_tree.yview)
        self.completed_tree.configure(yscrollcommand=scrollbar.set)
        
        self.completed_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
    
    def _load_orders(self):
        self.pending_orders = get_pending_orders()
        self.completed_orders = get_completed_orders()
        self._refresh_pending_list()
        self._refresh_completed_list()
    
    def _refresh_pending_list(self):
        self.pending_tree.delete(*self.pending_tree.get_children())
        
        for i, order in enumerate(self.pending_orders):
            time_str = order.received_at.strftime("%H:%M:%S")
            txn_id = order.transaction_id or "-"
            self.pending_tree.insert("", "end", iid=order.order_id, values=(
                i + 1,
                order.order_id,
                order.student_name,
                order.phone,
                order.total_pages,
                f"{order.print_type}/{order.print_side[:1]}",
                f"₹{order.total_cost:.0f}",
                txn_id[:12] + "..." if len(txn_id) > 12 else txn_id,
                time_str,
            ))
        
        self.count_label.config(text=f"Pending: {len(self.pending_orders)}")
        self._update_buttons()
    
    def _refresh_completed_list(self):
        self.completed_tree.delete(*self.completed_tree.get_children())
        
        for order in self.completed_orders:
            completed_str = order.completed_at.strftime("%Y-%m-%d %H:%M") if order.completed_at else "-"
            txn_id = order.transaction_id or "-"
            self.completed_tree.insert("", "end", values=(
                order.order_id,
                order.student_name,
                order.total_pages,
                f"₹{order.total_cost:.0f}",
                txn_id,
                completed_str,
            ))
    
    def _on_select(self, event):
        self._update_buttons()
    
    def _update_buttons(self):
        selection = self.pending_tree.selection()
        has_selection = len(selection) > 0
        children = self.pending_tree.get_children()
        is_first = has_selection and children and selection[0] == children[0]
        
        state = tk.NORMAL if has_selection and is_first else tk.DISABLED
        self.open_btn.config(state=state)
        self.print_btn.config(state=state)
        self.complete_btn.config(state=state)
        self.delete_btn.config(state=tk.NORMAL if has_selection else tk.DISABLED)
    
    def _get_selected_order(self) -> Optional[PrintOrder]:
        selection = self.pending_tree.selection()
        if not selection:
            return None
        order_id = selection[0]
        return next((o for o in self.pending_orders if o.order_id == order_id), None)
    
    def _open_pdf(self):
        order = self._get_selected_order()
        if order and os.path.exists(order.local_file_path):
            os.startfile(order.local_file_path)
        elif order:
            messagebox.showerror("Error", "PDF file not found")
    
    def _print_order(self):
        order = self._get_selected_order()
        if not order or not os.path.exists(order.local_file_path):
            messagebox.showerror("Error", "PDF file not found")
            return
        try:
            os.startfile(order.local_file_path, "print")
            messagebox.showinfo("Printing", f"Sent to printer: {order.order_id}")
        except Exception as e:
            messagebox.showerror("Print Error", str(e))
    
    def _view_screenshot(self):
        """Open payment screenshot for manual verification"""
        order = self._get_selected_order()
        if not order:
            messagebox.showwarning("No Selection", "Please select an order first")
            return
        
        if order.payment_screenshot_path and os.path.exists(order.payment_screenshot_path):
            os.startfile(order.payment_screenshot_path)
        else:
            messagebox.showinfo("No Screenshot", 
                f"No payment screenshot available for order {order.order_id}.\n\n"
                f"Additional Info: {order.additional_info or 'None provided'}")
    
    def _complete_order(self):
        order = self._get_selected_order()
        if not order:
            return
        
        if not messagebox.askyesno("Confirm", f"Mark order {order.order_id} as complete?\nStudent will be notified."):
            return
        
        completed_at = datetime.now()
        update_order_status(order.order_id, "completed", completed_at)
        
        if order.fcm_token:
            base_url = self.config["ws_url"].replace("wss://", "https://").replace("/ws/xerox", "")
            threading.Thread(
                target=send_complete_notification,
                args=(base_url, self.config["api_token"], order.order_id,
                      order.fcm_token, order.student_name, order.total_pages),
                daemon=True
            ).start()
        
        try:
            if os.path.exists(order.local_file_path):
                os.remove(order.local_file_path)
            if order.payment_screenshot_path and os.path.exists(order.payment_screenshot_path):
                os.remove(order.payment_screenshot_path)
        except:
            pass
        
        self._load_orders()
        messagebox.showinfo("Complete", f"Order {order.order_id} marked as complete")
    
    def _delete_order(self):
        order = self._get_selected_order()
        if not order:
            return
        
        dialog = RejectDialog(self.root)
        self.root.wait_window(dialog.top)
        
        if not dialog.confirmed:
            return
        
        if order.fcm_token:
            base_url = self.config["ws_url"].replace("wss://", "https://").replace("/ws/xerox", "")
            threading.Thread(
                target=send_rejection_notification,
                args=(base_url, self.config["api_token"], order.order_id,
                      order.fcm_token, order.student_name, dialog.selected_reason),
                daemon=True
            ).start()
        
        delete_order(order.order_id)
        
        try:
            if os.path.exists(order.local_file_path):
                os.remove(order.local_file_path)
            if order.payment_screenshot_path and os.path.exists(order.payment_screenshot_path):
                os.remove(order.payment_screenshot_path)
        except:
            pass
        
        self._load_orders()
        messagebox.showinfo("Deleted", f"Order {order.order_id} deleted. Student notified.")
    
    def _toggle_pause(self):
        """Toggle service pause state"""
        base_url = self.config["ws_url"].replace("wss://", "https://").replace("/ws/xerox", "")
        new_pause_state = not self.is_paused
        
        def do_toggle():
            success = toggle_service_pause(base_url, self.config["api_token"], new_pause_state)
            self.root.after(0, lambda: self._update_pause_ui(success, new_pause_state))
        
        threading.Thread(target=do_toggle, daemon=True).start()
    
    def _update_pause_ui(self, success: bool, new_state: bool):
        if success:
            self.is_paused = new_state
            if self.is_paused:
                self.pause_btn.config(text="▶ Resume", bg=COLORS["warning"], fg="#1e1e1e")
            else:
                self.pause_btn.config(text="⏸ Pause", bg=COLORS["bg_tertiary"], fg=COLORS["fg"])
        else:
            messagebox.showerror("Error", "Failed to toggle service state")
    
    def _check_pause_status(self):
        """Check current pause status from server"""
        base_url = self.config["ws_url"].replace("wss://", "https://").replace("/ws/xerox", "")
        
        def check():
            status = get_service_status(base_url, self.config["api_token"])
            is_paused = status.get("paused", False)
            self.root.after(0, lambda: self._update_pause_ui(True, is_paused))
        
        threading.Thread(target=check, daemon=True).start()
    
    def _connect(self):
        self.ws_client = WebSocketClient(
            on_order=self._on_new_order,
            on_status=self._on_ws_status,
            on_error=self._on_ws_error,
            on_screenshot=self._on_screenshot,  # Handle screenshots that arrive after order
        )
        self.ws_client.connect(self.config["ws_url"], self.config["api_token"])
        
        self.connect_btn.config(state=tk.DISABLED)
        self.disconnect_btn.config(state=tk.NORMAL)
    
    def _disconnect(self):
        if self.ws_client:
            self.ws_client.disconnect()
            self.ws_client = None
        
        self.connect_btn.config(state=tk.NORMAL)
        self.disconnect_btn.config(state=tk.DISABLED)
        self._update_status("disconnected", "Disconnected")
    
    def _on_new_order(self, order: PrintOrder):
        save_order(order)
        self.root.after(0, self._load_orders)
        self.root.after(0, lambda: self.root.bell())
    
    def _on_screenshot(self, order_id: str, screenshot_path: str):
        """Called when screenshot arrives (may be after order is already saved)"""
        from database import update_screenshot_path
        update_screenshot_path(order_id, screenshot_path)
        # Refresh the order list to show updated screenshot availability
        self.root.after(0, self._load_orders)
        print(f"[UI] Screenshot linked to order {order_id}")
    
    def _on_ws_status(self, status: str, message: str):
        self.root.after(0, lambda: self._update_status(status, message))
    
    def _on_ws_error(self, error: str):
        self.root.after(0, lambda: messagebox.showerror("WebSocket Error", error))
    
    def _update_status(self, status: str, message: str):
        colors = {
            "connected": COLORS["success"],
            "connecting": COLORS["warning"],
            "reconnecting": COLORS["warning"],
            "disconnected": COLORS["error"],
            "error": COLORS["error"],
        }
        color = colors.get(status, COLORS["fg_dim"])
        self.status_label.config(text=f"● {message}", fg=color)
    
    def run(self):
        self.root.mainloop()


class RejectDialog:
    """Rejection reason dialog - Dark Mode"""
    def __init__(self, parent):
        self.confirmed = False
        self.selected_reason = "Order was not processed"
        
        reasons = [
            "Order was not processed",
            "Invalid payment screenshot",
            "Document file corrupted",
            "Duplicate order",
            "Student request",
            "Other"
        ]
        
        self.top = tk.Toplevel(parent)
        self.top.title("Delete Order")
        self.top.geometry("380x250")
        self.top.transient(parent)
        self.top.grab_set()
        self.top.configure(bg=COLORS["bg"])
        
        tk.Label(self.top, text="Select rejection reason:", font=("Segoe UI", 10),
                 bg=COLORS["bg"], fg=COLORS["fg"]).pack(pady=10)
        
        self.reason_var = tk.StringVar(value=reasons[0])
        for reason in reasons:
            tk.Radiobutton(self.top, text=reason, variable=self.reason_var, value=reason,
                           bg=COLORS["bg"], fg=COLORS["fg"], selectcolor=COLORS["bg_secondary"],
                           activebackground=COLORS["bg"]).pack(anchor="w", padx=20)
        
        btn_frame = tk.Frame(self.top, bg=COLORS["bg"])
        btn_frame.pack(pady=15)
        
        tk.Button(btn_frame, text="Delete & Notify", command=self._confirm,
                  bg=COLORS["error"], fg="white", width=15).pack(side=tk.LEFT, padx=10)
        tk.Button(btn_frame, text="Cancel", command=self.top.destroy,
                  bg=COLORS["bg_tertiary"], fg=COLORS["fg"], width=10).pack(side=tk.LEFT, padx=10)
    
    def _confirm(self):
        self.selected_reason = self.reason_var.get()
        self.confirmed = True
        self.top.destroy()


def main():
    login = LoginScreen()
    if not login.run():
        return
    
    app = XeroxManagerApp()
    app.run()


if __name__ == "__main__":
    main()
