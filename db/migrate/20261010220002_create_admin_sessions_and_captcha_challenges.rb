# Server-side state for two things that must not live only in the client's cookie:
#
#   admin_sessions      one row per signed-in browser. The cookie holds a random
#                       token; only its digest is stored. Signing out deletes the
#                       row, so a copied cookie stops working, and idle expiry is
#                       decided by the server, not by a timestamp the client holds.
#   captcha_challenges  one row per CAPTCHA image. Verifying deletes the row, which
#                       is what makes a challenge genuinely single-use: with the
#                       digest kept in a cookie-store session, replaying the
#                       original cookie would pass the same challenge repeatedly.
class CreateAdminSessionsAndCaptchaChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_sessions do |t|
      t.references :admin, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end
    add_index :admin_sessions, :token_digest, unique: true
    add_index :admin_sessions, :last_seen_at

    create_table :captcha_challenges do |t|
      t.string :digest, null: false
      t.datetime :expires_at, null: false

      t.datetime :created_at, null: false
    end
    add_index :captcha_challenges, :expires_at
  end
end
