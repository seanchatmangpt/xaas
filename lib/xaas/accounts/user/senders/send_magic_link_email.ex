defmodule Xaas.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender

  @impl true
  def send(user_or_email, token, _) do
    # if you get a user, its for a user that already exists.
    # if you get an email, then the user does not yet exist.

    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    IO.puts("""
    Hello, #{email}! Click this link to sign in:

    /auth/user/magic_link/?token=#{token}
    """)
  end
end
