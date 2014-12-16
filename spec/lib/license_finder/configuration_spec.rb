require "spec_helper"

module LicenseFinder
  describe Configuration do
    describe ".ensure_default" do
      it "should init and use saved config" do
        expect(Configuration::Persistence).to receive(:init)
        allow(Configuration::Persistence).to receive(:get).and_return('project_name' => 'Saved Project Name')

        expect(described_class.ensure_default.project_name).to eq('Saved Project Name')
      end
    end

    describe '.new' do
      it "should default missing attributes" do
        subject = described_class.new({})
        expect(subject.artifacts.dir).to eq(Pathname('./doc/'))
        expect(subject.gradle_command).to eq('gradle')
      end

      it "should default missing attributes even if they are saved as nils in the YAML file" do
        attributes = {
          "dependencies_file_dir" => nil,
          "project_name" => nil,
          "gradle_command" => nil
        }
        subject = described_class.new(attributes)
        expect(subject.artifacts.dir).to eq(Pathname('./doc/'))
        expect(subject.project_name).not_to be_nil
        expect(subject.gradle_command).to eq('gradle')
      end

      it "should set the all of the attributes on the instance" do
        attributes = {
          "dependencies_file_dir" => "some/path",
          "project_name" => "my_app",
          "gradle_command" => "./gradlew"
        }
        subject = described_class.new(attributes)
        expect(subject.artifacts.dir).to eq(Pathname("some/path"))
        expect(subject.project_name).to eq("my_app")
        expect(subject.gradle_command).to eq("./gradlew")
      end
    end

    describe "file paths" do
      it "should be relative to artifacts dir" do
        artifacts = described_class.new('dependencies_file_dir' => './elsewhere').artifacts
        expect(artifacts.dir).to eq(Pathname('./elsewhere'))
        expect(artifacts.decisions_file).to eq(Pathname('./elsewhere/dependency_decisions.yml'))
      end
    end

    describe "#project_name" do
      it "should default to the directory name" do
        allow(Dir).to receive(:getwd).and_return("/path/to/a_project")
        expect(described_class.new({}).project_name).to eq("a_project")
      end
    end

    describe "#save" do
      def attributes # can't be a let... the caching causes polution
        {
          'project_name' => "New Project Name",
          'dependencies_file_dir' => "./deps",
          'gradle_command' => './gradle'
        }
      end

      it "persists the configuration attributes" do
        expect(Configuration::Persistence).to receive(:set).with(attributes)
        described_class.new(attributes).save
      end
    end
  end

  describe Configuration::Persistence do
    describe ".get" do
      it "should use saved configuration" do
        file = double(:file,
                      :exist? => true,
                      :read => {'some' => 'config'}.to_yaml)
        allow(described_class).to receive(:file).and_return(file)

        expect(described_class.get).to eq({'some' => 'config'})
      end

      it "should not mind if config is not saved" do
        file = double(:file, :exist? => false)
        allow(described_class).to receive(:file).and_return(file)

        expect(file).not_to receive(:read)
        expect(described_class.get).to eq({})
      end
    end

    describe ".set" do
      let(:tmp_yml) { '.tmp.configuration_spec.yml' }

      after do
        File.delete(tmp_yml)
      end

      it "writes the configuration attributes to the yaml file" do
        allow(described_class).to receive(:file).and_return(Pathname.new(tmp_yml))

        described_class.set('some' => 'config')
        expect(described_class.get).to eq({'some' => 'config'})
      end
    end

    describe ".init" do
      it "initializes the config file" do
        file = double(:file, :exist? => false)
        allow(described_class).to receive(:file).and_return(file)

        expect(FileUtils).to receive(:cp).with(described_class.send(:file_template), file)
        described_class.init
      end

      it "does nothing if there is already a config file" do
        file = double(:file, :exist? => true)
        allow(described_class).to receive(:file).and_return(file)

        expect(FileUtils).not_to receive(:cp)
        described_class.init
      end
    end
  end
end
