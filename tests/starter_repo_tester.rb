require_relative "logger"
require_relative "starter_code_uncommenter"

class StarterRepoTester < TestHarness
  include Logger

  attr_reader :course, :language

  def initialize(course, language)
    @course = course
    @language = language
  end

  def self.from_repo_name(repo_name)
    course, language = repo_name.split("-starter-")
    self.new(course, language)
  end

  def do_test
    log_header("Testing starter: #{course}-starter-#{language}")

    assert dockerfiles.any?, "Expected a dockerfile to exist for #{slug}"

    log_info "Building image"
    build_image

    log_info "Executing starter repo script"
    assert_time_under(15) {
      assert_script_output("Your code goes here", expected_exit_code=1)
    }

    log_success "Script output verified"

    log_info "Uncommenting starter code..."
    diffs = StarterCodeUncommenter.new(starter_dir, language).uncomment
    diffs.each do |diff|
      if diff.to_s.empty?
        log_error("Expected uncommenting code to return a diff")
        log_error("Are you sure there's a contiguous block of comments after the 'Uncomment this' marker?")
        return
      end
      puts ""
      puts diff.to_s(:color)
      puts ""
    end

    log_info "Executing starter repo script with first stage uncommented"
    time_taken = assert_time_under(15) {
      assert_script_output("All tests ran successfully.")
    }

    log_success "Took #{time_taken} secs"
  end

  def starter_dir
    "compiled_starters/#{course}-starter-#{language}"
  end

  def dockerfile_path
    "dockerfiles/#{course}/#{language}-#{latest_version}"
  end

  def latest_dockerfile
    "#{course}-#{language}-#{latest_version}"
  end

  def latest_version
    dockerfiles
      .map { |dockerfile_name| dockerfile_name.sub(".Dockerfile", "") }
      .map { |dockerfile_name| dockerfile_name.split("-").last }
      .sort_by { |version| Gem::Version.new(version) }
      .last
  end

  def slug
    "#{course}-#{language_pack}-#{latest_version}"
  end

  def dockerfiles
    Dir["dockerfiles/#{course}/*.Dockerfile"]
      .map { |dockerfile_path| File.basename(dockerfile_path) }
      .select { |dockerfile_name| dockerfile_name.start_with?(language_pack) }
  end

  def language_pack
    language.eql?("javascript") ? "nodejs" : language
  end

  def dockerfile_path
    "dockerfiles/#{course}/#{language_pack}-#{latest_version}.Dockerfile"
  end

  def starter_dir
    "compiled_starters/#{course}-starter-#{language}"
  end

  def starter_tester_path
    ".starter_testers/#{course}"
  end

  def build_image
    assert_stdout_contains(
      "docker build -t #{slug} -f #{dockerfile_path} #{starter_dir}",
      "Successfully tagged #{slug}"
    )
  end

  def assert_script_output(expected_output, expected_exit_code=0)
    command = [
      "docker run",
      "-v #{File.expand_path(starter_dir)}:/app",
      "-v #{File.expand_path(starter_tester_path)}:/bin/tester",
      "#{slug} tester"
    ].join(" ")

    assert_stdout_contains(
      command,
      expected_output,
      expected_exit_code=expected_exit_code,
    )
  end
end
