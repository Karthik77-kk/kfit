// Cloudflare Pages Function: /api/contact
// Receives contact form submissions, validates input, and forwards to support@getkfit.app

interface Env {
  TURNSTILE_SECRET_KEY?: string;
  CONTACT_EMAIL?: string;
  SEND_EMAIL?: {
    send: (message: { from: string; to: string; subject: string; content: Array<{ type: string; value: string }> }) => Promise<void>;
  };
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export const onRequestOptions = async () => {
  return new Response(null, { headers: corsHeaders });
};

export const onRequestPost = async (context: { request: Request; env: Env }) => {
  const { request, env } = context;

  try {
    const body = (await request.json()) as {
      name?: string;
      contact?: string;
      topic?: string;
      message?: string;
      turnstileToken?: string;
    };

    const name = String(body.name || 'Anonymous').slice(0, 100);
    const contact = String(body.contact || '').trim().slice(0, 150);
    const topic = String(body.topic || 'General').slice(0, 50);
    const message = String(body.message || '').trim().slice(0, 4000);

    if (!contact || !message) {
      return new Response(
        JSON.stringify({ error: 'Contact and message are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Optional Cloudflare Turnstile Verification
    if (env.TURNSTILE_SECRET_KEY && body.turnstileToken) {
      const verifyFormData = new FormData();
      verifyFormData.append('secret', env.TURNSTILE_SECRET_KEY);
      verifyFormData.append('response', body.turnstileToken);
      verifyFormData.append('remoteip', request.headers.get('CF-Connecting-IP') || '');

      const verifyRes = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
        method: 'POST',
        body: verifyFormData,
      });

      const outcome = (await verifyRes.json()) as { success: boolean };
      if (!outcome.success) {
        return new Response(
          JSON.stringify({ error: 'CAPTCHA verification failed' }),
          { status: 403, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
        );
      }
    }

    const recipient = env.CONTACT_EMAIL || 'support@getkfit.app';

    // If Cloudflare Email Routing send binding is bound
    if (env.SEND_EMAIL && typeof env.SEND_EMAIL.send === 'function') {
      await env.SEND_EMAIL.send({
        from: `contact-form@getkfit.app`,
        to: recipient,
        subject: `[KFit Contact: ${topic}] from ${name}`,
        content: [
          {
            type: 'text/plain',
            value: `Topic: ${topic}\nName: ${name}\nSender Contact: ${contact}\nIP: ${request.headers.get('CF-Connecting-IP') || 'unknown'}\n\nMessage:\n${message}`,
          },
        ],
      });
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Message forwarded successfully' }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: 'Internal error processing request', details: err?.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
};
