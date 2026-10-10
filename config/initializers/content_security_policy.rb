# Content Security Policy.
#
# Production only: the Vite dev server needs inline scripts and a websocket that a
# strict policy would block, and development is local anyway. Everything the app
# ships is first-party (self-hosted fonts, bundled scripts and styles), so nothing
# is allowed from anywhere else. Inline style *attributes* are permitted because the
# UI sets a few widths (progress bars) from data; inline <style> blocks and
# scripts are not. The one inline <style> the page needs (Inertia's progress bar)
# is allowed by a fresh random nonce per request, handed to Inertia through the
# csp-nonce meta tag, rather than by a blanket 'unsafe-inline'.
unless Rails.env.local?
  Rails.application.configure do
    config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w[style-src]

    config.content_security_policy do |policy|
      policy.default_src :none
      policy.script_src :self
      policy.style_src :self
      policy.style_src_attr :unsafe_inline
      policy.img_src :self, :data
      policy.font_src :self
      policy.connect_src :self
      policy.object_src :none
      policy.base_uri :self
      policy.form_action :self
      policy.frame_ancestors :none
    end
  end
end
