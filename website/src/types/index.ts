export type UserRole = "call_center" | "reception" | "sales" | "manager";

export interface User {
  id: string;
  username: string;
  full_name: string;
  role: UserRole;
  phone: string | null;
  avatar_url: string | null;
  is_active: boolean;
  created_at: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
  user: User;
}

export interface DocumentOut {
  id: string;
  filename: string;
  original_name: string;
  content_type: string;
  url: string;
  uploaded_at: string;
  uploaded_by: string | null;
  notes: string | null;
}

export interface Customer {
  id: string;
  name: string;
  profession: string | null;
  address: string | null;
  phone: string;
  email: string | null;
  gender: "male" | "female" | null;
  call_center_id: string | null;
  call_center_name: string | null;
  call_center_avatar_url: string | null;
  how_knew: string | null;
  referral_buyer_name: string | null;
  sales_employee_id: string | null;
  sales_employee_name: string | null;
  sales_employee_avatar_url: string | null;
  notes: string | null;
  status: string | null;
  booking_id: string | null;
  documents: DocumentOut[];
  created_at: string;
  updated_at: string | null;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  pages: number;
}

export interface Visit {
  id: string;
  customer_id: string;
  visit_date: string;
  notes: string | null;
  sales_employee_id: string | null;
  sales_employee_name: string | null;
  sales_employee_avatar_url: string | null;
  recorded_by_avatar_url: string | null;
  recorded_by: string | null;
  recorded_by_name: string | null;
  created_at: string;
}

export interface Deal {
  id: string;
  customer_id: string;
  name: string;
  profession: string | null;
  email: string | null;
  phone: string;
  house_type: "house" | "villa";
  house_area: number | null;
  residential_block: string | null;
  house_number: string | null;
  total_price: number;
  payment_type: "cash" | "half_cash" | "installments";
  down_payment: number;
  status: "completed";
  notes: string | null;
  sales_employee_id: string;
  sales_employee_name: string | null;
  sales_employee_avatar_url: string | null;
  sale_date: string;
  created_at: string;
}
