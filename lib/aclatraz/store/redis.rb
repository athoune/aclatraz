begin
  require 'redis'
rescue LoadError
  raise "You must install the redis gem to use the Redis store"
end

module Aclatraz
  module Store
    # List of global roles are stored in ROLES set. Each suspect has its 
    # own key, which contains list of assigned roles. Roles are stored in
    # following format:
    #
    #   suspect.{:suspect_id}.roles:
    #     "role_name"
    #     "role_name/ClassName"
    #     "role_name/ObjectClass/object_id"
    class Redis
      include Aclatraz::Helpers
      
      ROLES_KEY         = "roles"
      SUSPECT_ROLES_KEY = "suspect.%s.roles"
      
      def initialize(*args) # :nodoc:
        @backend = if args.first.respond_to?(:sadd)
          args.first
        else
          ::Redis.new(*args)
        end
      end

      def set(role, suspect, object=nil)
        @backend.multi do
          @backend.sadd(ROLES_KEY, role.to_s) unless object
          @backend.sadd(SUSPECT_ROLES_KEY % suspect_id(suspect), pack(role.to_s, object))
        end
      end
      
      def roles(suspect=nil)
        if suspect
          @backend.smembers(SUSPECT_ROLES_KEY % suspect_id(suspect)).map {|role|
            role = unpack(role)
            role[0] if role.size == 1
          }.compact.uniq
        else
          @backend.smembers(ROLES_KEY)
        end
      end
      
      def check(role, suspect, object=nil)
        @backend.sismember(SUSPECT_ROLES_KEY % suspect_id(suspect), pack(role.to_s, object)) or begin
          object && !object.is_a?(Class) ? check(role, suspect, object.class) : false
        end
      end
      
      def delete(role, suspect, object=nil)
        @backend.srem(SUSPECT_ROLES_KEY % suspect_id(suspect), pack(role.to_s, object))
      end
      
      def clear
        @backend.flushdb
      end
    end # Redis
  end # Store
end # Aclatraz
