require 'spec_helper'

describe 'CF Python Buildpack' do
  let(:browser)  { Machete::Browser.new(app) }
  let(:app_name) { 'flask_web_app' }

  subject(:app)  { Machete.deploy_app(app_name) }

  after { Machete::CF::DeleteApp.new.execute(app) }

  context 'with an unsupported dependency' do
    let(:app_name) { 'unsupported_version' }

    it 'displays a nice error messages and gracefully fails' do
      expect(app).to_not be_running
      expect(app).to_not have_logged 'Downloaded ['
      expect(app).to have_logged 'DEPENDENCY MISSING IN MANIFEST: python 99.99.99'
    end
  end

  it "should not display the allow-all-external deprecation message" do
    expect(app).to be_running
    expect(app).to_not have_logged 'DEPRECATION: --allow-all-external has been deprecated and will be removed in the future'
  end

  context 'with cached buildpack dependencies', :cached do
    context 'app has dependencies' do
      context 'with Python 2' do
        let(:app_name) { 'flask_web_app' }

        specify do
          expect(app).to be_running(60)

          browser.visit_path('/')
          expect(browser).to have_body('Hello, World!')
          expect(app).to have_logged(/Downloaded \[file:\/\/.*\]/)

          expect(app).not_to have_internet_traffic
        end
      end

      context 'with Python 3' do
        let(:app_name) { 'flask_web_app_python_3' }

        specify do
          expect(app).to be_running(120)

          browser.visit_path('/')
          expect(browser).to have_body('Hello, World!')

          expect(app).not_to have_internet_traffic
        end
      end
    end

    context 'Warning when pip has mercurial dependencies' do
      let(:log_file) { File.open('log/integration.log', 'r') }
      let(:app_name) { 'mercurial_requirements' }

      before do
        log_file.readlines
      end

      specify do
        expect(app).not_to be_running(0)
        expect(app).to have_logged 'Cloud Foundry does not support Pip Mercurial dependencies while in offline-mode. Vendor your dependencies if they do not work.'
      end
    end
  end

  context 'without cached buildpack dependencies', :uncached do
    context 'app has dependencies' do
      context 'with Python 2' do
        let(:app_name) { 'flask_web_app' }

        specify do
          expect(app).to be_running(60)

          browser.visit_path('/')
          expect(browser).to have_body('Hello, World!')
          expect(app).to have_logged(/Downloaded \[https:\/\/.*\]/)
        end
      end

      context 'with Python 3' do
        let(:app_name) { 'flask_web_app_python_3' }

        specify do
          expect(app).to be_running(60)

          browser.visit_path('/')
          expect(browser).to have_body('Hello, World!')
        end
      end
    end

    context 'app has non-vendored dependencies' do
      let(:app_name) { 'flask_web_app_not_vendored' }

      specify do
        expect(app).to be_running(60)

        browser.visit_path('/')
        expect(browser).to have_body('Hello, World!')
      end

      it "uses a proxy during staging if present" do
        expect(app).to use_proxy_during_staging
      end
    end
  end
end
