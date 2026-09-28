defmodule Xaas.Ultracode.WorkerEnvTest do
  @moduledoc """
  Chicago-style qualification of the worker environment law: the real
  compiled policy, and a real `/usr/bin/env` subprocess spawned with the
  built environment. Fixture credentials only.
  """
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.WorkerEnv

  doctest WorkerEnv

  @denied ~w(GITHUB_TOKEN GH_TOKEN AWS_SECRET_ACCESS_KEY SLACK_BOT_TOKEN JIRA_API_TOKEN
             INTERNAL_API_TOKEN DATABASE_URL FOO_SECRET MY_API_KEY)
  @admitted ~w(PATH HOME LC_ALL XAAS_LEASE_ID XAAS_MCP_TOKEN ANTHROPIC_API_KEY
               ZCODE_SUBAGENT_MAX_TURNS ZCODE_OCEL)

  describe "allowed?/1" do
    for name <- @denied do
      test "refuses #{name}" do
        refute WorkerEnv.allowed?(unquote(name))
      end
    end

    for name <- @admitted do
      test "admits #{name}" do
        assert WorkerEnv.allowed?(unquote(name))
      end
    end

    test "refuses names the policy never mentions" do
      refute WorkerEnv.allowed?("RANDOM_UNLISTED_VAR")
      refute WorkerEnv.allowed?(nil)
    end
  end

  # Court falsify-env (v26.9.27) witnessed every name below crossing the
  # first policy draft; each is a regression fixture now.
  @court_leaks [
    "ZCODE_Token",
    "ZCODE_github_token",
    "LC_github_token",
    "ZCODE_APIKEY",
    "ZCODE_ApiKey",
    "ZCODE_PASS",
    "ZCODE_PWD",
    "ASDF_HEX_PASS",
    "LC_PASS",
    "ZCODE_AUTH",
    "ZCODE_AUTHORIZATION",
    "ZCODE_BEARER",
    "ZCODE_COOKIE",
    "ZCODE_SESSION",
    "ZCODE_TOKEN_V2",
    "ZCODE_TOKEN2",
    "ZCODE_CLIENT_SECRET_B64",
    "ZCODE_PRIVATE_KEY_PEM",
    "ZCODE_API_KEY_FILE",
    "ASDF_GH_TOKEN_FILE",
    "ZCODE_TOKEN ",
    "ZCODE_TOKEN\t",
    "ZCODE_TOKEN\r",
    "ZCODE_TOKEN\n",
    "ZCODE_SECRET\u200B",
    "ERL_AFLAGS",
    "ERL_FLAGS",
    "ERL_ZFLAGS",
    "ERL_LIBS",
    "ELIXIR_ERL_OPTIONS",
    "NODE_EXTRA_CA_CERTS",
    "NODE_OPTIONS",
    "HEX_HOME",
    "CARGO_HOME",
    "PGPASSWORD",
    "GIT_ASKPASS",
    "SSH_AUTH_SOCK",
    "HTTPS_PROXY",
    "https_proxy"
  ]

  describe "court falsify-env regressions" do
    test "every witnessed leak name is refused" do
      leaked = Enum.filter(@court_leaks, &WorkerEnv.allowed?/1)
      assert leaked == []
    end

    test "dropped/2 names every refused variable, not only the obvious one" do
      parent = Map.new(@court_leaks, &{&1, "fixture-leak"}) |> Map.put("PATH", "/bin")
      assert WorkerEnv.dropped(parent, []) == Enum.sort(Enum.uniq(@court_leaks))
      assert WorkerEnv.build(parent, []) == [{"PATH", "/bin"}]
    end

    test "a URL-valued admitted name cannot carry userinfo credentials" do
      parent = %{
        "ANTHROPIC_BASE_URL" => "https://user:fixture-pass@api.example.test",
        "XAAS_MCP_URL" => "http://localhost:4000/internal-api/execution/mcp"
      }

      assert WorkerEnv.build(parent, []) == [
               {"XAAS_MCP_URL", "http://localhost:4000/internal-api/execution/mcp"}
             ]

      assert WorkerEnv.dropped(parent, []) == ["ANTHROPIC_BASE_URL"]
    end
  end

  # Court env2 + bypass2 (v26.9.27, second pass) witnessed these crossing.
  @court2_ambient ~w(LC_SECRETS LC_TOKENS LC_APITOKEN NODE_PATH XAAS_ALLOW_SUBAGENTS)
  @court2_explicit ~w(SECRETS APP_TOKENS API_KEYS DB_PASSWORDS GITLAB_ACCESSTOKEN MYSECRET
                      STRIPE_SECRETKEY APITOKEN V2TOKEN NPM_CONFIG__AUTHTOKEN DSN SENTRY_DSN
                      CONNECTION_STRING MONGO_URI DATABASE_URI STRIPE_SK VAULT_ROLE_ID AGE_IDENTITY
                      BUNDLE_RUBYGEMS__ORG KUBECONFIG DOCKER_CONFIG DOCKER_HOST CLOUDSDK_CONFIG
                      GNUPGHOME CURL_HOME XDG_CONFIG_HOME VAULT_ADDR OP_CONNECT_HOST LD_PRELOAD
                      DYLD_LIBRARY_PATH BASH_ENV ENV PERL5OPT PERL5LIB PYTHONSTARTUP RUBYOPT
                      XAAS_SURFACE_PATH XAAS_ALLOW_SUBAGENTS)

  describe "court env2/bypass2 regressions" do
    test "ambient leak names are refused" do
      assert Enum.filter(@court2_ambient, &WorkerEnv.allowed?/1) == []
    end

    test "explicit pairs cannot carry credential or loader names" do
      explicit = Enum.map(@court2_explicit, &{&1, "/fixture"})
      assert WorkerEnv.build(%{}, [], explicit) == []
    end

    test "credential-bearing VALUES are refused under any name" do
      explicit = [
        {"UPSTREAM_URL", "https://u:fixture-pass@host/x"},
        {"FOO_CONN", "Server=h;User Id=u;Password=fixture"},
        {"FAKE_LOG", "/tmp/fake-log"}
      ]

      assert WorkerEnv.build(%{}, [], explicit) == [{"FAKE_LOG", "/tmp/fake-log"}]
    end

    test "URL-valued names refuse parser-differential and query/fragment smuggling" do
      for v <- ~w(https:u:s3cr3t@h/mcp u:SECRET@h:4000/mcp https://h/mcp?token=SECRET
                  https://h/mcp#SECRET ftp://h/x) do
        assert WorkerEnv.build(%{"XAAS_MCP_URL" => v}, []) == [], v
      end

      assert WorkerEnv.build(%{"XAAS_MCP_URL" => "http://localhost:4000/mcp"}, []) ==
               [{"XAAS_MCP_URL", "http://localhost:4000/mcp"}]
    end
  end

  describe "court env3 regressions" do
    test "LC_ is no longer an open prefix; standard locale names still cross" do
      refute WorkerEnv.allowed?("LC_JWT")
      refute WorkerEnv.allowed?("LC_WEBHOOK")
      assert WorkerEnv.allowed?("LC_ALL")
      assert WorkerEnv.allowed?("LC_CTYPE")
    end

    test "secret-shaped VALUES never cross under an admitted name" do
      parent = %{
        "ZCODE_OCEL" => "sk-ant-FIXTURE",
        "TERM" => "xterm;https://u:p@h",
        "TMPDIR" => "/tmp/eyJhbGciOiJIUzI1NiJ9/",
        "LANG" => "en_US.UTF-8",
        "ANTHROPIC_API_KEY" => "sk-ant-fixture-model-grant"
      }

      assert WorkerEnv.build(parent, []) == [
               {"ANTHROPIC_API_KEY", "sk-ant-fixture-model-grant"},
               {"LANG", "en_US.UTF-8"}
             ]
    end

    test "a granted URL name still refuses userinfo" do
      assert WorkerEnv.build(%{"ANTHROPIC_BASE_URL" => "https://u:p@h"}, []) == []
    end

    test "explicit secret name classes and loader/trust names are refused" do
      names = ~w(JWT_SIGNING WEBHOOK_HMAC SERVICE_JWT MFA_OTP TOTP_SEED WALLET_MNEMONIC
                 WEBHOOK_URL KEYFILE SIGNINGKEY ACCESSKEY TWILIO_SID PRIVKEY CI_JOB_JWT
                 SIGNER_HMAC ALERT_HOOK CA_BUNDLE CURL_CA_BUNDLE REQUESTS_CA_BUNDLE HEX_MIRROR
                 HEX_UNSAFE_HTTPS MIX_EXS MIX_DEPS_PATH OPENAI_BASE_URL BOTO_CONFIG ZDOTDIR
                 PROMPT_COMMAND PERLLIB PERL_MB_OPT)

      assert WorkerEnv.build(%{}, [], Enum.map(names, &{&1, "fixture"})) == []
    end

    test "explicit innocuous names carrying webhook/JWT values are refused" do
      explicit = [
        {"NOTIFY_TARGET", "https://hooks.slack.com/services/T/B/X"},
        {"BUILD_BLOB", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0"},
        {"FAKE_LOG", "/tmp/fake-log"}
      ]

      assert WorkerEnv.build(%{}, [], explicit) == [{"FAKE_LOG", "/tmp/fake-log"}]
    end
  end

  describe "build/2" do
    test "additions override parent but cannot smuggle a denied credential" do
      parent = %{"PATH" => "/bin", "HOME" => "/h", "GITHUB_TOKEN" => "fixture-gh"}

      additions = [
        {"GITHUB_TOKEN", "fixture-gh-smuggled"},
        {"HOME", "/lease"},
        {"XAAS_LEASE_ID", "lease-fixture"}
      ]

      env = WorkerEnv.build(parent, additions)

      assert env == [{"HOME", "/lease"}, {"PATH", "/bin"}, {"XAAS_LEASE_ID", "lease-fixture"}]
      assert WorkerEnv.key_names(env) == ["HOME", "PATH", "XAAS_LEASE_ID"]
      assert WorkerEnv.dropped(parent, additions) == ["GITHUB_TOKEN"]
    end

    test "is deterministic regardless of input order" do
      parent = %{"TERM" => "x", "PATH" => "/bin", "LC_ALL" => "C"}

      assert WorkerEnv.build(parent, []) ==
               WorkerEnv.build(Map.new(Enum.reverse(Map.to_list(parent))), [])

      assert Enum.map(WorkerEnv.build(parent, []), &elem(&1, 0)) == ["LC_ALL", "PATH", "TERM"]
    end

    test "env_argv starts from an empty environment" do
      assert WorkerEnv.env_argv([{"A", "1"}, {"B", "2"}]) == ["-i", "A=1", "B=2"]
    end
  end

  describe "real subprocess" do
    defp run_env(argv) do
      port =
        Port.open({:spawn_executable, "/usr/bin/env"}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: argv
        ])

      collect(port, "")
    end

    defp collect(port, acc) do
      receive do
        {^port, {:data, data}} -> collect(port, acc <> data)
        {^port, {:exit_status, status}} -> {acc, status}
      after
        15_000 -> flunk("subprocess timed out; output so far: #{acc}")
      end
    end

    defp parent do
      Map.merge(System.get_env(), %{
        "GITHUB_TOKEN" => "fixture-gh",
        "AWS_SECRET_ACCESS_KEY" => "fixture-aws",
        "SLACK_BOT_TOKEN" => "fixture-slack"
      })
    end

    test "negative credential: child environment carries no forge/cloud/chat credential" do
      additions = [{"XAAS_LEASE_ID", "lease-fixture"}, {"GITHUB_TOKEN", "fixture-gh"}]
      env = WorkerEnv.build(parent(), additions)

      {out, 0} = run_env(WorkerEnv.env_argv(env) ++ ["/usr/bin/env"])

      refute out =~ "fixture-gh"
      refute out =~ "fixture-aws"
      refute out =~ "fixture-slack"
      assert out =~ "XAAS_LEASE_ID=lease-fixture"

      assert Enum.all?(
               WorkerEnv.dropped(parent(), additions),
               &(&1 not in WorkerEnv.key_names(env))
             )

      assert "GITHUB_TOKEN" in WorkerEnv.dropped(parent(), additions)
    end

    test "positive: child can still run a local primitive via PATH" do
      env = WorkerEnv.build(parent(), [{"XAAS_LEASE_ID", "lease-fixture"}])
      assert {"PATH", _} = List.keyfind(env, "PATH", 0)

      {out, 0} = run_env(WorkerEnv.env_argv(env) ++ ["git", "--version"])
      assert out =~ ~r/^git version /
    end
  end
end
