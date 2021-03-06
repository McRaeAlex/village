defmodule VillageWeb.FeedLive do
  use VillageWeb, :live_view

  alias Village.Feed
  alias Village.Feed.Post
  alias VillageWeb.PostComponent

  @impl true
  def mount(_params, %{"current_user" => current_user}, socket) do
    if connected?(socket) do
      Feed.subscribe()
    end

    socket =
      assign(socket,
        changeset: Feed.change_post(%Post{}),
        current_user: current_user,
        page: 1,
        per_page: 10
      )
      |> load_posts()

    {:ok, socket, temporary_assigns: [posts: []]}
  end

  @impl true
  def handle_event("new", %{"post" => new_post}, socket) do
    user = socket.assigns[:current_user]

    case Feed.create_post(user, new_post) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:notice, "Post created!")
         |> update(:posts, fn posts -> [post | posts] end)
         |> assign(:update_action, :prepend)}

      {:error, changeset} ->
        {:noreply, update(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("edit", params, socket) do
    # TODO: handle editing posts
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"post_id" => post_id}, socket) do
    user = socket.assigns[:current_user]
    post = Feed.get_post!(post_id)

    with :ok <- Bodyguard.permit(Feed, :delete, user, post),
         {:ok, post} <- Feed.delete_post(post) do
      socket =
        socket
        |> put_flash(:notice, "Post deleted successfully.")
        |> update(:posts, fn posts -> [post | posts] end)

      {:noreply, socket}
    else
      {:error, :unauthorized} ->
        {:noreply, socket |> put_flash(:error, "Your not authorized to delete that post!")}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete post. Already deleted")}

      {:error, _reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete post.")}
    end
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    socket =
      socket
      |> update(:page, &(&1 + 1))
      |> load_posts()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply,
     socket |> update(:posts, fn posts -> [post | posts] end) |> assign(:update_action, :prepend)}
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    {:noreply, socket |> update(:posts, fn posts -> [post | posts] end)}
  end

  defp load_posts(socket) do
    page = socket.assigns.page
    per_page = socket.assigns.per_page

    assign(socket,
      posts: Feed.list_posts(page, per_page),
      update_action: :append
    )
  end
end
