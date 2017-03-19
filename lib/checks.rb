require_relative "./printer"

module Checks
  class Check
    def initialize(name, list_title = nil, end_check = true)
      @name = name
      @list_title = list_title
      @end_check = end_check
    end

    def check?(&blk)
      @check = blk
    end

    def exec(&blk)
      @exec = blk
    end

    def list(&blk)
      @set_list = blk
    end

    def run
      if !@set_list.nil? && @exec.nil? && @call.nil?
        @list_title = @name if @list_title.nil?
        list_run
      else
        exec_run
      end
    end

    def list_run
      return if @set_list.nil?
      @list = @set_list.call
      print_list
    end

    def exec_run
      return if @exec.nil? && @call.nil?
      if @check.call
        return logger.puts_coloured("{{green: ✓}} #{@name} (already done)")
      else
        print_list
        logger.put_header(@name)
        successful = true
        begin
          @exec.call
        rescue => e
          logger.puts_failure(e.message)
          successful = false
        end
      end
      if @end_check == false || (successful && @check.call)
        logger.put_footer
      else
        logger.puts_failure("Check failed after executing task")
        logger.put_footer false
      end
    end

    def print_list
      return if @list_title.nil?
      logger.put_header(@list_title)
      @list.each { |item| logger.log item }
      logger.put_footer
    end

    def logger
      Printer
    end
  end

  @checks = []
  def self.new_check(name, list_title: nil, end_check: true, &blk)
    check = Check.new(name, list_title, end_check).tap { |c| c.instance_eval(&blk) }
    @checks.push(check)
    check
  end

  def self.reset
    @checks = []
  end

  def self.run
    @checks.each(&:run)
  end
end

# Checks.new_check "hi" do
#   check? do
#     @h == 1
#   end

#   exec do
#     logger.log "nope"
#     @h = 1
#   end
# end

# Checks.new_check "list", list_title: "listing" do
#   check? do
#     @list = ["ab", "cb"]
#     @h == 1
#   end

#   exec do
#     logger.log "nope"
#     @h = 1
#   end
# end

# Checks.new_check "no end checks", end_check: false do
#   check? do
#   end

#   exec do
#     logger.log "nope"
#     @h = 1
#   end
# end

# a = Checks.new_check "list only" do
#   list do
#     ["a", "b"]
#   end
# end

# Checks.run
