

module EventMachine
	#
	# Creates a 'Deferred' object which represents a task which will finish in the future.
	#
	class Defer
		
		class Promise
		end
		
		class DeferredPromise < Promise
			def initialize(defer)
				@defer = defer
			end
			
			
			def then(callback = nil, errback = nil, &blk)
				result = Defer.new
				
				callback ||= blk
				
				wrappedCallback = proc { |value|
					begin
						result.resolve(callback.nil? ? value : callback.call(value))
					rescue => e
						warn "\nUnhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
						result.reject(e);
					end
				}
				
				wrappedErrback = proc { |reason|
					begin
						result.resolve(errback.nil? ? Defer.reject(reason) : errback.call(reason))
					rescue => e
						warn "Unhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
						result.reject(e);
					end
				}
				
				#
				# Schedule as we are touching arrays
				# => Everything else is locally scoped
				#
				EM.schedule do
					pending_array = pending
					
					if pending_array.nil?
						value.then(wrappedCallback, wrappedErrback)
					else
						pending_array << [wrappedCallback, wrappedErrback]
					end
				end
				
				result.promise
			end
			
			
			protected
			
			
			def pending
				@defer.instance_eval { @pending }
			end
			
			def value
				@defer.instance_eval { @value }
			end
		end
		
		
		class ResolvedPromise < Promise
			def initialize(response, error = false)
				raise ArgumentError if error && response.is_a?(Promise)
				@error = error
				@response = response
			end
			
			def then(callback = nil, errback = nil, &blk)
				result = Defer.new
				
				callback ||= blk
				
				EM.next_tick {
					if @error
						result.resolve(errback.nil? ? Defer.reject(@response) : errback.call(@response))
					else
						result.resolve(callback.nil? ? @response : callback.call(@response))
					end
				}
				
				result.promise
			end
		end
		
		
		def initialize
			@pending = []
			@value = nil
		end
		
		
		def resolve(val = nil)
			EM.schedule do
				if !!@pending
					callbacks = @pending
					@pending = nil
					@value = ref(val)
					
					if callbacks.length > 0
						callbacks.each do |callback|
							@value.then(callback[0], callback[1])
						end
					end
				end
			end
		end
		
		
		def reject(reason = nil)
			resolve(Defer.reject(reason))
		end
		
		
		def promise
			DeferredPromise.new( self )
		end
		
		
		#
		# Creates a promise that is resolved as rejected with the specified reason. This api should be
		# used to forward rejection in a chain of promises. If you are dealing with the last promise in
		# a promise chain, you don't need to worry about it.
		#
		# When comparing deferreds/promises to the familiar behaviour of try/catch/throw, think of
		# reject as the raise keyword in Ruby. This also means that if you "catch" an error via
		# a promise error callback and you want to forward the error to the promise derived from the
		# current promise, you have to "rethrow" the error by returning a rejection constructed via
		# reject.
		#
		# @example handling rejections
		#
		#   #!/usr/bin/env ruby
		#
		#   require 'rubygems' # or use Bundler.setup
		#   require 'eventmachine'
		#
		#   promiseB = promiseA.then(lambda {|result|
		#     # success: do something and resolve promiseB with the old or a new result
		#     return result
		#   }, lambda {|reason|
		#     # error: handle the error if possible and resolve promiseB with newPromiseOrValue,
		#     #        otherwise forward the rejection to promiseB
		#     if canHandle(reason)
		#       # handle the error and recover
		#       return newPromiseOrValue
		#     end
		#     return Defer.reject(reason)
		#   })
		#
		# @param [Object] reason constant, message, exception or an object representing the rejection reason.
		def self.reject(reason = nil)
			return ResolvedPromise.new( reason, true )	# A resolved failed promise
		end
		
		#
		# Combines multiple promises into a single promise that is resolved when all of the input
		# promises are resolved.
		#
		# @param [Promise] a number of promises that will be combined into a single promise
		# @returns [Promise] Returns a single promise that will be resolved with an array of values,
		#   each value corresponding to the promise at the same index in the `promises` array. If any of
		#   the promises is resolved with a rejection, this resulting promise will be resolved with the
		#   same rejection.
		def self.all(*promises)
			deferred = Defer.new
			counter = promises.length
			results = []
			
			if counter > 0
				promises.each_index do |index|
					ref(promises[index]).then(proc {|result|
						if results[index].nil?
							results[index] = result
							counter -= 1
							deferred.resolve(results) if counter <= 0
						end
						result
					}, proc {|reason|
						if results[index].nil?
							deferred.reject(reason)
						end
						reason
					})
				end
			else
				deferred.resolve(results)
			end
			
			return deferred.promise
		end
		
		
		protected
		
		
		def self.ref(value)
			return value if value.is_a?(Promise)
			return ResolvedPromise.new( value )			# A resolved success promise
		end
		
		def ref(value)
			Defer.ref(value)
		end
	end

end
