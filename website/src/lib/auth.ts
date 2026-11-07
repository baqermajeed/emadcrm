import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { User, UserRole } from "@/types";
import { storage } from "@/lib/storage";
import { AUTH_SESSION_EXPIRED_EVENT, ApiRequestError, getCurrentUser } from "@/lib/api";

export const WEB_ALLOWED_ROLES: UserRole[] = ["manager", "sales", "call_center"];

export function canAccessWebsite(role: UserRole): boolean {
  return WEB_ALLOWED_ROLES.includes(role);
}

export function useProtectedPage(allowedRoles?: UserRole[]) {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const validatedTokenRef = useRef<string | null>(null);
  const allowedRolesKey = allowedRoles?.join("|") ?? "";

  useEffect(() => {
    function handleSessionExpired() {
      storage.clear();
      validatedTokenRef.current = null;
      setUser(null);
      setToken(null);
      setLoading(false);
      router.replace("/");
    }

    window.addEventListener(AUTH_SESSION_EXPIRED_EVENT, handleSessionExpired);
    return () => {
      window.removeEventListener(AUTH_SESSION_EXPIRED_EVENT, handleSessionExpired);
    };
  }, [router]);

  useEffect(() => {
    const currentUser = storage.getUser();
    const currentToken = storage.getToken();

    if (!currentUser || !currentToken) {
      router.replace("/");
      return;
    }

    if (!canAccessWebsite(currentUser.role)) {
      storage.clear();
      router.replace("/");
      return;
    }

    if (allowedRoles && !allowedRoles.includes(currentUser.role)) {
      router.replace(getRoleHome(currentUser.role));
      return;
    }

    setUser((previous) => (previous?.id === currentUser.id ? previous : currentUser));
    setToken((previous) => (previous === currentToken ? previous : currentToken));

    // Prevent repeated /auth/me requests when the effect re-runs with the same token.
    if (validatedTokenRef.current === currentToken) {
      setLoading(false);
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const freshUser = await getCurrentUser(currentToken);
        if (cancelled) return;
        if (!canAccessWebsite(freshUser.role)) {
          storage.clear();
          router.replace("/");
          return;
        }
        if (allowedRoles && !allowedRoles.includes(freshUser.role)) {
          router.replace(getRoleHome(freshUser.role));
          return;
        }
        storage.setUser(freshUser);
        const latestToken = storage.getToken() ?? currentToken;
        validatedTokenRef.current = latestToken;
        setToken((previous) => (previous === latestToken ? previous : latestToken));
        setUser(freshUser);
      } catch (error) {
        if (error instanceof ApiRequestError && error.statusCode === 401) {
          storage.clear();
          validatedTokenRef.current = null;
          setUser(null);
          setToken(null);
          router.replace("/");
          return;
        }
        // Keep using cached user if non-auth network request fails.
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
    // Including `router` here may re-trigger this effect repeatedly in dev and spam /auth/me.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowedRolesKey]);

  return { user, token, loading };
}

export function getRoleHome(role: UserRole): string {
  if (role === "call_center") return "/call-center";
  if (role === "reception") return "/reception/customers";
  if (role === "sales") return "/sales";
  return "/manager";
}
