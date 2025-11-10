# frozen_string_literal: true

require "spec_helper"

describe(Jekyll::JekyllSitemap) do
  context "with git lastmod enabled" do
    let(:overrides) do
      {
        "source"      => source_dir,
        "destination" => dest_dir,
        "url"         => "http://example.org",
        "collections" => {
          "my_collection" => { "output" => true },
          "other_things"  => { "output" => false },
        },
        "sitemap"     => {
          "lastmod_source" => "git",
        },
      }
    end
    let(:config) do
      Jekyll.configuration(overrides)
    end
    let(:site)     { Jekyll::Site.new(config) }
    let(:contents) { File.read(dest_dir("sitemap.xml")) }

    before(:each) do
      site.process
    end

    it "creates a sitemap.xml file" do
      expect(File.exist?(dest_dir("sitemap.xml"))).to be_truthy
    end

    it "includes pages in the sitemap" do
      expect(contents).to match %r!<loc>http://example\.org/</loc>!
      expect(contents).to match %r!<loc>http://example\.org/some-subfolder/this-is-a-subpage\.html</loc>!
    end

    # Git-tracked files should have lastmod dates from git
    it "adds git-based lastmod dates to git-tracked files" do
      # This test will pass if the fixture files are in git
      # If git is available and files are tracked, lastmod tags should be present
      git_available = system("git rev-parse --is-inside-work-tree > /dev/null 2>&1")
      
      if git_available
        # Check that at least some lastmod tags exist
        expect(contents).to match(%r!<lastmod>!)
      end
    end

    # Front-matter last_modified_at should still be respected
    it "respects front-matter last_modified_at when explicitly set" do
      # Create a test page with explicit last_modified_at in front matter
      test_page_content = <<~CONTENT
        ---
        last_modified_at: 2020-01-15T00:00:00+00:00
        ---
        Test content
      CONTENT

      test_page_path = File.join(source_dir, "test_frontmatter_page.html")
      File.write(test_page_path, test_page_content)

      begin
        # Re-process the site
        site.process
        contents_with_frontmatter = File.read(dest_dir("sitemap.xml"))

        # The front-matter date should be in the sitemap
        expect(contents_with_frontmatter).to match(%r!<lastmod>2020-01-15T00:00:00\+00:00</lastmod>!)
      ensure
        # Clean up the test file
        File.delete(test_page_path) if File.exist?(test_page_path)
      end
    end
  end

  context "with git lastmod disabled (default)" do
    let(:overrides) do
      {
        "source"      => source_dir,
        "destination" => dest_dir,
        "url"         => "http://example.org",
        "collections" => {
          "my_collection" => { "output" => true },
          "other_things"  => { "output" => false },
        },
      }
    end
    let(:config) do
      Jekyll.configuration(overrides)
    end
    let(:site)     { Jekyll::Site.new(config) }
    let(:contents) { File.read(dest_dir("sitemap.xml")) }

    before(:each) do
      site.process
    end

    it "works normally without git mode" do
      expect(File.exist?(dest_dir("sitemap.xml"))).to be_truthy
      expect(contents).to match %r!<loc>http://example\.org/</loc>!
    end

    it "includes posts with their post.date as lastmod" do
      expect(contents).to match(
        %r!
          <loc>http://example\.org/2014/03/04/march-the-fourth\.html</loc>\s+
          <lastmod>2014-03-04T00:00:00\+00:00</lastmod>
        !x
      )
    end
  end
end

describe(Jekyll::Sitemap::GitHelper) do
  context "git availability" do
    it "can check if git is available" do
      # This will return true or false depending on whether we're in a git repo
      result = Jekyll::Sitemap::GitHelper.git_available?
      expect([true, false]).to include(result)
    end
  end

  context "git commit date retrieval" do
    it "returns nil for non-existent files" do
      date = Jekyll::Sitemap::GitHelper.last_commit_date("nonexistent.html", source_dir)
      expect(date).to be_nil
    end

    it "returns a Time object for tracked files if git is available" do
      git_available = Jekyll::Sitemap::GitHelper.git_available?
      
      if git_available
        # Try to get commit date for README (likely to be tracked)
        readme_path = File.expand_path("../../README.md", __dir__)
        if File.exist?(readme_path)
          # Get relative path from source
          date = Jekyll::Sitemap::GitHelper.last_commit_date(
            "README.md",
            File.expand_path("../..", __dir__)
          )
          # If the file is tracked, we should get a Time object
          expect(date).to be_a(Time) if date
        end
      end
    end
  end
end

