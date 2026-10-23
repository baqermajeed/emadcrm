import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { User, UserRole } from "@/types";
import { storage } from "@/lib/storage";

export function useProtectedPage(allowedRoles?: UserRole[]) {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const currentUser = storage.getUser();
    const currentToken = storage.getToken();

    if (!currentUser || !currentToken) {
      router.replace("/");
      return;
    }

    if (allowedRoles && !allowedRoles.includes(currentUser.role)) {
      router.replace(getRoleHome(currentUser.role));
      return;
    }

    setUser(currentUser);
    setToken(currentToken);
    setLoading(false);
  }, [allowedRoles, router]);

  return { user, token, loading };
}

export function getRoleHome(role: UserRole): string {
  if (role === "reception") return "/reception/customers";
  if (role === "sales") return "/sales";
  return "/manager";
}
