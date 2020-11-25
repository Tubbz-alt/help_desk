defmodule HelpDesk.Broadway do
  use Broadway
  use Appsignal.Instrumentation.Decorators

  require Logger

  alias Broadway.Message

  def start_link(_opts) do
    producer_module = Application.fetch_env!(:help_desk, :producer)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: producer_module
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        default: [
          batch_size: 10,
          batch_timeout: 2000
        ]
      ]
    )
  end

  @impl true
  @decorate transaction(:queue)
  def handle_message(_, %Message{data: data} = message, _context) do
    %{resource: resource, request_id: request_id} =
      data
      |> URI.decode()
      |> Bottle.Core.V1.Bottle.decode()

    Logger.metadata(request_id: request_id)

    with {:error, reason} <- notify_handler(resource) do
      Appsignal.send_error(%RuntimeError{}, "Failed Help Desk Message", [], %{}, nil, fn transaction ->
        transaction
        |> Appsignal.Transaction.set_sample_data("reason", reason)
        |> Appsignal.Transaction.set_sample_data("resource", elem(resource, 0))
      end)
    end

    message
  end

  @impl true
  def handle_batch(_, messages, _, _) do
    messages
  end

  @impl true
  def handle_failed([failed_message], _context) do
    Appsignal.send_error(%RuntimeError{}, "Failed Broadway Message", [], %{}, nil, fn transaction ->
      Appsignal.Transaction.set_sample_data(transaction, "message", %{data: failed_message.data})
    end)

    [failed_message]
  end

  defp notify_handler({:user_created, %{user: user}}) do
    Logger.debug("Handling User Created message")
    Users.sync(user)
  end

  defp notify_handler({:question_created, question}) do
    Logger.debug("Handling Question Created message")
    Tickets.create(question)
  end

  defp notify_handler({:organization_created, %{organization: organization}}) do
    Logger.debug("Handling Organization Created message")
    Organizations.create(organization)
  end

  defp notify_handler({:organization_joined, %{organization: organization, user: user}}) do
    Logger.debug("Handling Organization Joined message")
    Organizations.join(organization, user)
  end

  defp notify_handler({:organization_left, %{user: user}}) do
    Logger.debug("Handling Organization Left message")
    Organizations.leave(user)
  end

  defp notify_handler(_) do
    Logger.debug("Ignoring message")
    :ignored
  end
end
