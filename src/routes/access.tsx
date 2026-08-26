import { createFileRoute } from "@tanstack/react-router";
import { AccountAccess } from "@/components/account/AccountAccess";

export const Route = createFileRoute("/access")({
  head: () => ({
    meta: [
      { title: "Sign in — No More Copium" },
      {
        name: "description",
        content: "Create an account with your access code, or sign in with Google.",
      },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AccessPage,
});

function AccessPage() {
  return (
    <main className="flex min-h-[100dvh] items-center justify-center bg-background px-4 py-8">
      <div className="w-full max-w-md text-center">
        <h1 className="text-3xl font-bold tracking-tight text-foreground">No More Copium</h1>
        <p className="mt-1.5 text-[0.9375rem] text-muted-foreground">
          Create an account with your access code, or sign in with Google.
        </p>
        <div className="mt-6">
          <AccountAccess />
        </div>
      </div>
    </main>
  );
}
