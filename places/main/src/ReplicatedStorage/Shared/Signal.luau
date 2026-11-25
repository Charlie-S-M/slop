--!strict

-- A minimal signal for cross-module events. Handlers run in their own threads, so one that
-- errors or yields never blocks the rest.

export type Connection = { Disconnect: (self: Connection) -> () }

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { (T...) -> () } = {}
	local signal = {}

	function signal.Connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		table.insert(handlers, handler)
		local connection = {}
		function connection.Disconnect(_conn: Connection)
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
		return connection :: Connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return signal :: any
end

return Signal
