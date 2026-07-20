defmodule MatomeApi.Storage.ObjectStoreTest do
  use ExUnit.Case, async: false

  alias MatomeApi.Storage.ObjectStore

  test "delegates deletes to a configured one-argument adapter" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.put_env(:matome_api, ObjectStore, adapter: __MODULE__.Adapter)

    on_exit(fn -> restore(previous) end)

    assert :ok = ObjectStore.delete_object("owners/1/items/file")
    assert_receive {:deleted, "owners/1/items/file"}
    Process.delete({__MODULE__.Adapter, :parent})
  end

  test "delegates deletes to a configured two-argument adapter" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.put_env(:matome_api, ObjectStore, adapter: {__MODULE__.ArgAdapter, self()})

    on_exit(fn -> restore(previous) end)

    assert :ok = ObjectStore.delete_object("owners/1/items/file")
    assert_receive {:deleted_with_arg, "owners/1/items/file"}
  end

  test "delegates bounded prefix reads to the configured adapter" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.put_env(:matome_api, ObjectStore, adapter: {__MODULE__.ArgAdapter, self()})

    on_exit(fn -> restore(previous) end)

    assert {:ok, "%PDF-"} = ObjectStore.get_prefix("owners/1/items/file", 8192)
    assert_receive {:prefix_read, "owners/1/items/file", 8192}
    assert {:error, :invalid_prefix_size} = ObjectStore.get_prefix("owners/1/items/file", 8193)
  end

  test "treats successful and missing HTTP deletes as reaped" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.put_env(:matome_api, ObjectStore, http_client: __MODULE__.SuccessHttp)

    on_exit(fn -> restore(previous) end)

    assert :ok = ObjectStore.delete_object("owners/1/items/file")

    Application.put_env(:matome_api, ObjectStore, http_client: __MODULE__.MissingHttp)
    assert :ok = ObjectStore.delete_object("owners/1/items/file")
  end

  test "reads only the requested prefix through an HTTP range request" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.put_env(:matome_api, ObjectStore, http_client: __MODULE__.RangeHttp)

    on_exit(fn -> restore(previous) end)

    assert {:ok, "%PDF-"} = ObjectStore.get_prefix("owners/1/items/file", 5)
  end

  test "returns HTTP delete failures" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.put_env(:matome_api, ObjectStore, http_client: __MODULE__.FailingHttp)

    on_exit(fn -> restore(previous) end)

    assert {:error, {:storage_delete_failed, 500, ~c"boom"}} =
             ObjectStore.delete_object("owners/1/items/file")

    Application.put_env(:matome_api, ObjectStore, http_client: __MODULE__.ErrorHttp)
    assert {:error, :closed} = ObjectStore.delete_object("owners/1/items/file")
  end

  test "rejects invalid storage keys before an HTTP delete" do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.delete_env(:matome_api, ObjectStore)

    on_exit(fn -> restore(previous) end)

    assert {:error, :invalid_storage_key} = ObjectStore.delete_object("../../secret")
  end

  defmodule Adapter do
    def delete_object(storage_key) do
      send(Process.get({__MODULE__, :parent}), {:deleted, storage_key})
      :ok
    end
  end

  defmodule ArgAdapter do
    def delete_object(storage_key, parent) do
      send(parent, {:deleted_with_arg, storage_key})
      :ok
    end

    def get_prefix(storage_key, max_bytes, parent) do
      send(parent, {:prefix_read, storage_key, max_bytes})
      {:ok, "%PDF-"}
    end
  end

  defmodule SuccessHttp do
    def request(:delete, _request, [], []),
      do: {:ok, {{~c"HTTP/1.1", 204, ~c"No Content"}, [], ~c""}}
  end

  defmodule MissingHttp do
    def request(:delete, _request, [], []),
      do: {:ok, {{~c"HTTP/1.1", 404, ~c"Not Found"}, [], ~c""}}
  end

  defmodule FailingHttp do
    def request(:delete, _request, [], []),
      do: {:ok, {{~c"HTTP/1.1", 500, ~c"Oops"}, [], ~c"boom"}}
  end

  defmodule ErrorHttp do
    def request(:delete, _request, [], []), do: {:error, :closed}
  end

  defmodule RangeHttp do
    def request(:get, {_url, headers}, [], []) do
      if {~c"range", ~c"bytes=0-4"} in headers do
        {:ok,
         {{~c"HTTP/1.1", 206, ~c"Partial Content"}, [{~c"content-range", ~c"bytes 0-4/1000000"}],
          ~c"%PDF-"}}
      else
        {:ok, {{~c"HTTP/1.1", 400, ~c"Bad Request"}, [], ~c"missing range"}}
      end
    end
  end

  setup do
    Process.put({__MODULE__.Adapter, :parent}, self())
    :ok
  end

  defp restore(nil), do: Application.delete_env(:matome_api, ObjectStore)
  defp restore(previous), do: Application.put_env(:matome_api, ObjectStore, previous)
end
