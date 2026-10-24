import type { Customer, LoginResponse, PaginatedResponse, User } from "@/types";

const baseURL = "/api/backend";

function withPath(path: string): string {
  const trimmedBase = baseURL.replace(/\/+$/, "");
  const trimmedPath = path.replace(/^\/+/, "");
  return `${trimmedBase}/${trimmedPath}`;
}

export class ApiRequestError extends Error {
  statusCode?: number;

  constructor(message: string, statusCode?: number) {
    super(message);
    this.name = "ApiRequestError";
    this.statusCode = statusCode;
  }
}

async function parseApiError(response: Response): Promise<ApiRequestError> {
  const fallbackMessage = `Request failed with status ${response.status}`;
  try {
    const body = (await response.json()) as { detail?: string };
    return new ApiRequestError(body.detail || fallbackMessage, response.status);
  } catch {
    return new ApiRequestError(fallbackMessage, response.status);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(withPath(path), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {})
    }
  });

  if (!response.ok) {
    throw await parseApiError(response);
  }

  return (await response.json()) as T;
}

export async function login(username: string, password: string): Promise<LoginResponse> {
  return request<LoginResponse>("auth/login", {
    method: "POST",
    body: JSON.stringify({ username, password })
  });
}

export async function listCustomers(token: string, search = ""): Promise<PaginatedResponse<Customer>> {
  const params = new URLSearchParams({ page_size: "50", sort_dir: "desc" });
  if (search.trim()) params.set("search", search.trim());

  return request<PaginatedResponse<Customer>>(`customers?${params.toString()}`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
}

export async function getCustomer(token: string, customerId: string): Promise<Customer> {
  return request<Customer>(`customers/${customerId}`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
}

export interface UpdateCustomerPayload {
  status?: string | null;
  notes?: string | null;
}

export async function updateCustomer(
  token: string,
  customerId: string,
  payload: UpdateCustomerPayload
): Promise<Customer> {
  return request<Customer>(`customers/${customerId}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });
}

export async function uploadCustomerDocument(
  token: string,
  customerId: string,
  file: File,
  notes?: string
): Promise<void> {
  const formData = new FormData();
  formData.append("file", file);
  if (notes?.trim()) formData.append("notes", notes.trim());

  const response = await fetch(withPath(`customers/${customerId}/documents`), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: formData
  });

  if (!response.ok) throw await parseApiError(response);
}

export interface CreateDealPayload {
  customer_id: string;
  name: string;
  phone: string;
  house_type: "house" | "villa";
  total_price: number;
  payment_type: "cash" | "half_cash" | "installments";
  down_payment: number;
  profession?: string | null;
  email?: string | null;
  house_area?: number | null;
  residential_block?: string | null;
  house_number?: string | null;
  notes?: string | null;
}

export async function createDeal(token: string, payload: CreateDealPayload): Promise<void> {
  await request("deals", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });
}

export interface UpdateUserPayload {
  username?: string;
  full_name?: string;
  phone?: string | null;
  password?: string;
}

export async function updateUserProfile(
  token: string,
  userId: string,
  payload: UpdateUserPayload
): Promise<User> {
  const candidatePaths = [`users/${userId}`, "auth/me", "users/me"];
  let lastError: ApiRequestError | null = null;

  for (const path of candidatePaths) {
    try {
      return await request<User>(path, {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
    } catch (error) {
      if (error instanceof ApiRequestError) {
        lastError = error;
        if (error.statusCode === 403 || error.statusCode === 404 || error.statusCode === 405) {
          continue;
        }
      }
      throw error;
    }
  }

  if (lastError?.statusCode === 403) {
    throw new ApiRequestError("ليس لديك صلاحية تعديل معلومات الحساب.", 403);
  }
  throw lastError ?? new ApiRequestError("تعذر تحديث معلومات الموظف.");
}

export async function uploadUserAvatar(
  token: string,
  userId: string,
  file: Blob,
  filename: string
): Promise<User> {
  const candidatePaths = [`users/${userId}/avatar`, "auth/me/avatar", "users/me/avatar"];
  let lastError: ApiRequestError | null = null;

  for (const path of candidatePaths) {
    const formData = new FormData();
    formData.append("file", file, filename);

    const response = await fetch(withPath(path), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`
      },
      body: formData
    });

    if (response.ok) {
      return (await response.json()) as User;
    }

    const apiError = await parseApiError(response);
    lastError = apiError;
    if (apiError.statusCode === 403 || apiError.statusCode === 404 || apiError.statusCode === 405) {
      continue;
    }
    throw apiError;
  }

  if (lastError?.statusCode === 403) {
    throw new ApiRequestError("ليس لديك صلاحية تحديث صورة الحساب.", 403);
  }
  throw lastError ?? new ApiRequestError("تعذر تحديث صورة الموظف.");
}
