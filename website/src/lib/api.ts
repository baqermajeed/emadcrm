import type {
  Booking,
  BookingSource,
  BookingStatus,
  Customer,
  CustomerSalesNote,
  Deal,
  LiveSummary,
  LoginResponse,
  PaginatedResponse,
  User,
  Visit
} from "@/types";
import { storage } from "@/lib/storage";

const baseURL = "/api/backend";
export const AUTH_SESSION_EXPIRED_EVENT = "auth:session-expired";
let refreshTokenPromise: Promise<string | null> | null = null;

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

function stringifyApiDetail(detail: unknown, fallbackMessage: string): string {
  if (typeof detail === "string" && detail.trim()) return detail;
  if (typeof detail === "number" || typeof detail === "boolean") return String(detail);

  if (Array.isArray(detail)) {
    const messages = detail
      .map((item) => {
        if (typeof item === "string" && item.trim()) return item;
        if (item && typeof item === "object") {
          const record = item as Record<string, unknown>;
          const msg = record.msg ?? record.message ?? record.detail;
          return typeof msg === "string" && msg.trim() ? msg : null;
        }
        return null;
      })
      .filter((value): value is string => Boolean(value));
    if (messages.length) return messages.join(" - ");
  }

  if (detail && typeof detail === "object") {
    const record = detail as Record<string, unknown>;
    const direct =
      record.detail ??
      record.message ??
      record.msg ??
      record.error ??
      record.non_field_errors;
    const normalizedDirect = stringifyApiDetail(direct, "");
    if (normalizedDirect) return normalizedDirect;

    const entries = Object.entries(record)
      .map(([key, value]) => {
        const normalized = stringifyApiDetail(value, "");
        return normalized ? `${key}: ${normalized}` : null;
      })
      .filter((value): value is string => Boolean(value));
    if (entries.length) return entries.join(" - ");
  }

  return fallbackMessage;
}

async function parseApiError(response: Response): Promise<ApiRequestError> {
  const fallbackMessage = `Request failed with status ${response.status}`;
  try {
    const body = (await response.json()) as { detail?: unknown; message?: unknown; error?: unknown };
    const message = stringifyApiDetail(body.detail ?? body.message ?? body.error, fallbackMessage);
    return new ApiRequestError(message, response.status);
  } catch {
    return new ApiRequestError(fallbackMessage, response.status);
  }
}

function getAuthorization(headers?: HeadersInit): string | null {
  const normalized = new Headers(headers);
  const value = normalized.get("authorization");
  return value && value.trim() ? value.trim() : null;
}

function shouldSkipRefresh(path: string): boolean {
  const normalizedPath = path.replace(/^\/+/, "").toLowerCase();
  return normalizedPath === "auth/login" || normalizedPath === "auth/refresh";
}

function emitSessionExpired(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new Event(AUTH_SESSION_EXPIRED_EVENT));
}

async function refreshAccessToken(): Promise<string | null> {
  if (refreshTokenPromise) return refreshTokenPromise;

  refreshTokenPromise = (async () => {
    const response = await fetch(withPath("auth/refresh"), {
      method: "POST",
      credentials: "include",
      cache: "no-store",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      throw await parseApiError(response);
    }

    const payload = (await response.json()) as Partial<LoginResponse> & {
      token?: string;
    };
    const refreshedToken =
      (typeof payload.access_token === "string" && payload.access_token.trim()
        ? payload.access_token.trim()
        : null) ??
      (typeof payload.token === "string" && payload.token.trim() ? payload.token.trim() : null);

    if (!refreshedToken) {
      throw new ApiRequestError("Refresh token response did not include access token.", 500);
    }

    storage.setToken(refreshedToken);
    if (payload.user) storage.setUser(payload.user);
    return refreshedToken;
  })().finally(() => {
    refreshTokenPromise = null;
  });

  return refreshTokenPromise;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const initialHeaders = new Headers(init?.headers ?? {});
  if (!(init?.body instanceof FormData) && !initialHeaders.has("Content-Type")) {
    initialHeaders.set("Content-Type", "application/json");
  }

  const doFetch = async (headers: Headers): Promise<Response> =>
    fetch(withPath(path), {
      ...init,
      credentials: "include",
      headers
    });

  let response = await doFetch(initialHeaders);

  if (response.status === 401 && !shouldSkipRefresh(path)) {
    const authHeader = getAuthorization(initialHeaders);
    if (authHeader?.toLowerCase().startsWith("bearer ")) {
      try {
        const refreshedToken = await refreshAccessToken();
        if (refreshedToken) {
          const retryHeaders = new Headers(initialHeaders);
          retryHeaders.set("Authorization", `Bearer ${refreshedToken}`);
          response = await doFetch(retryHeaders);
        }
      } catch {
        emitSessionExpired();
      }
    }
  }

  if (!response.ok) {
    const apiError = await parseApiError(response);
    if (response.status === 401) {
      emitSessionExpired();
    }
    throw apiError;
  }

  return (await response.json()) as T;
}

export async function login(username: string, password: string): Promise<LoginResponse> {
  return request<LoginResponse>("auth/login", {
    method: "POST",
    body: JSON.stringify({ username, password })
  });
}

export async function getCurrentUser(token: string): Promise<User> {
  return request<User>("auth/me", {
    headers: {
      Authorization: `Bearer ${token}`
    }
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

export interface ListBookingsParams {
  search?: string;
  status?: BookingStatus;
  fromDate?: string;
  toDate?: string;
  page?: number;
  pageSize?: number;
  sortDir?: "asc" | "desc";
}

export async function listBookings(
  token: string,
  params: ListBookingsParams = {}
): Promise<PaginatedResponse<Booking>> {
  const query = new URLSearchParams({
    page: String(params.page ?? 1),
    page_size: String(params.pageSize ?? 50),
    sort_dir: params.sortDir ?? "desc"
  });
  if (params.search?.trim()) query.set("search", params.search.trim());
  if (params.status) query.set("status", params.status);
  if (params.fromDate) query.set("from_date", params.fromDate);
  if (params.toDate) query.set("to_date", params.toDate);

  return request<PaginatedResponse<Booking>>(`bookings?${query.toString()}`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
}

export interface UpsertBookingPayload {
  name: string;
  phone: string;
  governorate: string;
  source: BookingSource;
  visit_date: string;
  notes?: string | null;
}

export async function createBooking(token: string, payload: UpsertBookingPayload): Promise<Booking> {
  return request<Booking>("bookings", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });
}

export async function updateBooking(
  token: string,
  bookingId: string,
  payload: UpsertBookingPayload
): Promise<Booking> {
  return request<Booking>(`bookings/${bookingId}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });
}

export async function getLiveSummary(token: string): Promise<LiveSummary> {
  return request<LiveSummary>("reports/live-summary", {
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

export interface UpdateDealPayload {
  name?: string;
  phone?: string;
  profession?: string | null;
  email?: string | null;
  house_type?: "house" | "villa";
  payment_type?: "cash" | "half_cash" | "installments";
  total_price?: number;
  down_payment?: number;
  house_area?: number | null;
  residential_block?: string | null;
  house_number?: string | null;
  notes?: string | null;
}

export async function updateDeal(token: string, dealId: string, payload: UpdateDealPayload): Promise<void> {
  await request(`deals/${dealId}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });
}

export async function listCustomerVisits(token: string, customerId: string): Promise<Visit[]> {
  return request<Visit[]>(`visits/customer/${customerId}`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
}

export interface CreateVisitPayload {
  customer_id: string;
  visit_date?: string;
  notes?: string | null;
}

export async function createVisit(token: string, payload: CreateVisitPayload): Promise<void> {
  await request("visits", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });
}

export async function listCustomerDeals(token: string, customerId: string): Promise<Deal[]> {
  const params = new URLSearchParams({
    customer_id: customerId,
    page_size: "50",
    sort_dir: "desc"
  });
  const data = await request<PaginatedResponse<Deal>>(`deals?${params.toString()}`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  return data.items;
}

export async function listCustomerSalesNotes(
  token: string,
  customerId: string
): Promise<CustomerSalesNote[]> {
  return request<CustomerSalesNote[]>(`customers/${customerId}/sales-notes`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
}

export async function addCustomerSalesNote(
  token: string,
  customerId: string,
  note: string
): Promise<CustomerSalesNote> {
  return request<CustomerSalesNote>(`customers/${customerId}/sales-notes`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify({ note })
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
