require_relative "./printer"

module Tasks
  class Task
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

    def list_logger(&blk)
      @list_logger = blk
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
      sucessful = true
      logger.put_header(@list_title)
      @list.each do |item|
        unless @list_logger.nil?
          result = @list_logger.call(item)
          sucessful = false if result == false
          next
        end
        logger.log item
      end
      logger.put_footer sucessful
    end

    def logger
      Printer
    end
  end

  @tasks = []
  def self.new_task(name, list_title: nil, end_check: true, &blk)
    check = Task.new(name, list_title, end_check).tap { |c| c.instance_eval(&blk) }
    @tasks.push(check)
    check
  end

  def self.reset
    @tasks = []
  end

  def self.run
    @tasks.each(&:run)
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
