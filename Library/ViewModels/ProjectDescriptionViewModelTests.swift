@testable import KsApi
@testable import Library
// swiftlint:disable force_unwrapping
import Prelude
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import WebKit
import XCTest

final class ProjectDescriptionViewModelTests: TestCase {
  private let vm: ProjectDescriptionViewModelType = ProjectDescriptionViewModel()

  private let configurePledgeCTAViewContext = TestObserver<PledgeCTAContainerViewContext, Never>()
  private let configurePledgeCTAViewErrorEnvelope = TestObserver<ErrorEnvelope, Never>()
  private let configurePledgeCTAViewProject = TestObserver<Project, Never>()
  private let configurePledgeCTAViewIsLoading = TestObserver<Bool, Never>()
  private let configurePledgeCTAViewRefTag = TestObserver<RefTag?, Never>()
  private let goBackToProject = TestObserver<(), Never>()
  private let goToMessageDialog = TestObserver<(MessageSubject, Koala.MessageDialogContext), Never>()
  private let goToRewardsProject = TestObserver<Project, Never>()
  private let goToRewardsRefTag = TestObserver<RefTag?, Never>()
  private let goToSafariBrowser = TestObserver<URL, Never>()

  private let isLoading = TestObserver<Bool, Never>()
  private let loadWebViewRequest = TestObserver<URLRequest, Never>()
  private let pledgeCTAContainerViewIsHidden = TestObserver<Bool, Never>()
  private let showErrorAlert = TestObserver<NSError, Never>()

  override func setUp() {
    super.setUp()

    self.vm.outputs.configurePledgeCTAContainerView
      .map(first)
      .map(\.left)
      .skipNil()
      .map(first)
      .observe(self.configurePledgeCTAViewProject.observer)

    self.vm.outputs.configurePledgeCTAContainerView
      .map(first)
      .map(\.left)
      .skipNil()
      .map(second)
      .observe(self.configurePledgeCTAViewRefTag.observer)

    self.vm.outputs.configurePledgeCTAContainerView
      .map(first)
      .map(\.right)
      .skipNil()
      .observe(self.configurePledgeCTAViewErrorEnvelope.observer)

    self.vm.outputs.configurePledgeCTAContainerView.map(second)
      .observe(self.configurePledgeCTAViewIsLoading.observer)
    self.vm.outputs.configurePledgeCTAContainerView.map(third)
      .observe(self.configurePledgeCTAViewContext.observer)

    self.vm.outputs.goBackToProject.observe(self.goBackToProject.observer)
    self.vm.outputs.goToMessageDialog.observe(self.goToMessageDialog.observer)
    self.vm.outputs.goToSafariBrowser.observe(self.goToSafariBrowser.observer)
    self.vm.outputs.goToRewards.map(first).observe(self.goToRewardsProject.observer)
    self.vm.outputs.goToRewards.map(second).observe(self.goToRewardsRefTag.observer)
    self.vm.outputs.isLoading.observe(self.isLoading.observer)
    self.vm.outputs.loadWebViewRequest.observe(self.loadWebViewRequest.observer)
    self.vm.outputs.pledgeCTAContainerViewIsHidden.observe(self.pledgeCTAContainerViewIsHidden.observer)
    self.vm.outputs.showErrorAlert.map { $0 as NSError }.observe(self.showErrorAlert.observer)
  }

  func testGoBackToProject() {
    let project = .template
      |> Project.lens.id .~ 42
      |> Project.lens.urls.web.project .~ "https://www.kickstarter.com/projects/1/42"

    self.vm.inputs.configureWith(value: (project, nil))
    self.vm.inputs.viewDidLoad()

    self.isLoading.assertValues([true])

    self.loadWebViewRequest.assertValueCount(1)

    let request = URLRequest(url: URL(string: project.urls.web.project)!)

    let navigationAction = WKNavigationActionData(
      navigationType: .linkActivated,
      request: request,
      sourceFrame: WKFrameInfoData(mainFrame: true, request: request),
      targetFrame: WKFrameInfoData(mainFrame: true, request: request)
    )

    self.vm.inputs.decidePolicyFor(navigationAction: navigationAction)
    self.vm.inputs.webViewDidStartProvisionalNavigation()

    XCTAssertEqual(
      WKNavigationActionPolicy.cancel.rawValue,
      self.vm.outputs.decidedPolicyForNavigationAction.rawValue
    )

    self.vm.inputs.webViewDidFinishNavigation()

    self.isLoading.assertValues([true, false])

    self.loadWebViewRequest.assertValueCount(1)
    self.goBackToProject.assertValueCount(1)
    self.goToMessageDialog.assertValueCount(0)
    self.goToSafariBrowser.assertValueCount(0)
  }

  func testGoToMessageDialog() {
    let project = .template
      |> Project.lens.id .~ 42
      |> Project.lens.urls.web.project .~ "https://www.kickstarter.com/projects/1/42"

    self.vm.inputs.configureWith(value: (project, nil))
    self.vm.inputs.viewDidLoad()

    self.loadWebViewRequest.assertValueCount(1)

    let request = URLRequest(url: URL(string: project.urls.web.project + "/messages/new")!)
    let navigationAction = WKNavigationActionData(
      navigationType: .linkActivated,
      request: request,
      sourceFrame: WKFrameInfoData(mainFrame: true, request: request),
      targetFrame: WKFrameInfoData(mainFrame: true, request: request)
    )

    self.vm.inputs.decidePolicyFor(navigationAction: navigationAction)
    self.vm.inputs.webViewDidStartProvisionalNavigation()

    XCTAssertEqual(
      WKNavigationActionPolicy.cancel.rawValue,
      self.vm.outputs.decidedPolicyForNavigationAction.rawValue
    )

    self.scheduler.advance()
    self.vm.inputs.webViewDidFinishNavigation()

    self.isLoading.assertValues([true, false])
    self.loadWebViewRequest.assertValueCount(1)
    self.goBackToProject.assertValueCount(0)
    self.goToMessageDialog.assertValueCount(1)
    self.goToSafariBrowser.assertValueCount(0)
  }

  func testGoToRewards() {
    self.vm.inputs.configureWith(value: (.template, .discovery))
    self.vm.inputs.viewDidLoad()

    self.goToRewardsProject.assertDidNotEmitValue()
    self.goToRewardsRefTag.assertDidNotEmitValue()

    self.vm.inputs.pledgeCTAButtonTapped(with: .viewRewards)

    self.goToRewardsProject.assertValues([.template])
    self.goToRewardsRefTag.assertValues([.discovery])
  }

  func testGoToSafari() {
    let project = .template
      |> Project.lens.id .~ 42
      |> Project.lens.urls.web.project .~ "https://www.kickstarter.com/projects/1/42"

    self.vm.inputs.configureWith(value: (project, nil))
    self.vm.inputs.viewDidLoad()

    self.loadWebViewRequest.assertValueCount(1)

    let request = URLRequest(url: URL(string: "https://www.somewhere.com/else")!)
    let navigationAction = WKNavigationActionData(
      navigationType: .linkActivated,
      request: request,
      sourceFrame: WKFrameInfoData(mainFrame: true, request: request),
      targetFrame: WKFrameInfoData(mainFrame: true, request: request)
    )

    self.vm.inputs.decidePolicyFor(navigationAction: navigationAction)
    self.vm.inputs.webViewDidStartProvisionalNavigation()

    XCTAssertEqual(
      WKNavigationActionPolicy.cancel.rawValue,
      self.vm.outputs.decidedPolicyForNavigationAction.rawValue
    )
    XCTAssertEqual(["Opened External Link"], self.trackingClient.events)
    XCTAssertEqual(["project_description"], self.trackingClient.properties(forKey: "context"))

    self.scheduler.advance()
    self.vm.inputs.webViewDidFinishNavigation()

    self.isLoading.assertValues([true, false])
    self.loadWebViewRequest.assertValueCount(1)
    self.goBackToProject.assertValueCount(0)
    self.goToMessageDialog.assertValueCount(0)
    self.goToSafariBrowser.assertValueCount(1)
  }

  func testDescriptionRequest() {
    let project = Project.template

    self.vm.inputs.configureWith(value: (project, nil))
    self.vm.inputs.viewDidLoad()

    self.loadWebViewRequest.assertValueCount(1)

    let request = URLRequest(url: URL(string: project.urls.web.project + "/description")!)
    let navigationAction = WKNavigationActionData(
      navigationType: .other,
      request: request,
      sourceFrame: WKFrameInfoData(mainFrame: true, request: request),
      targetFrame: WKFrameInfoData(mainFrame: true, request: request)
    )

    self.vm.inputs.decidePolicyFor(navigationAction: navigationAction)
    self.vm.inputs.webViewDidStartProvisionalNavigation()

    XCTAssertEqual(
      WKNavigationActionPolicy.allow.rawValue,
      self.vm.outputs.decidedPolicyForNavigationAction.rawValue
    )

    self.scheduler.advance()
    self.vm.inputs.webViewDidFinishNavigation()

    self.isLoading.assertValues([true, false])
    self.loadWebViewRequest.assertValueCount(1)
    self.goBackToProject.assertValueCount(0)
    self.goToMessageDialog.assertValueCount(0)
    self.goToSafariBrowser.assertValueCount(0)
  }

  func testIFrameRequest() {
    let project = Project.template

    self.vm.inputs.configureWith(value: (project, nil))
    self.vm.inputs.viewDidLoad()

    self.loadWebViewRequest.assertValueCount(1)

    let request = URLRequest(url: URL(string: "https://www.youtube.com/watch")!)
    let navigationAction = WKNavigationActionData(
      navigationType: .other,
      request: request,
      sourceFrame: WKFrameInfoData(mainFrame: true, request: request),
      targetFrame: WKFrameInfoData(mainFrame: false, request: request)
    )

    self.vm.inputs.decidePolicyFor(navigationAction: navigationAction)
    self.vm.inputs.webViewDidStartProvisionalNavigation()

    XCTAssertEqual(
      WKNavigationActionPolicy.allow.rawValue,
      self.vm.outputs.decidedPolicyForNavigationAction.rawValue,
      "Loading non-main frame requests permitted, e.g. youtube."
    )

    self.scheduler.advance()
    self.vm.inputs.webViewDidFinishNavigation()

    self.isLoading.assertValues([true, false])
    self.loadWebViewRequest.assertValueCount(1)
    self.goBackToProject.assertValueCount(0)
    self.goToMessageDialog.assertValueCount(0)
    self.goToSafariBrowser.assertValueCount(0)
  }

  func testError() {
    let project = Project.template

    self.vm.inputs.configureWith(value: (project, nil))
    self.vm.inputs.viewDidLoad()

    let request = URLRequest(url: URL(string: project.urls.web.project)!)

    let navigationAction = WKNavigationActionData(
      navigationType: .linkActivated,
      request: request,
      sourceFrame: WKFrameInfoData(mainFrame: true, request: request),
      targetFrame: WKFrameInfoData(mainFrame: true, request: request)
    )

    self.vm.inputs.decidePolicyFor(navigationAction: navigationAction)
    self.vm.inputs.webViewDidStartProvisionalNavigation()

    let error = NSError(
      domain: "notonlinesorry", code: -666, userInfo: [NSLocalizedDescriptionKey: "Not online sorry"]
    )
    self.vm.inputs.webViewDidFailProvisionalNavigation(withError: error)

    self.showErrorAlert.assertValues([error])
  }

  // TODO: Complete tests once experiment is added
  // Include tests for pledgeCTAContainerViewIsHidden
  func testConfigurePledgeCTAContainerView_NonBacker_Control() {}
  func testConfigurePledgeCTAContainerView_Backer_Control() {}
  func testConfigurePledgeCTAContainerView_NonBacker_Variant1() {}
  func testConfigurePledgeCTAContainerView_Backer_Variant1() {}
  func testConfigurePledgeCTAContainerView_NonBacker_Variant2() {}
  func testConfigurePledgeCTAContainerView_Backer_Variant2() {}
}
