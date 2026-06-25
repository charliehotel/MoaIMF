import Foundation

extension ScanCoordinator {
  func scheduleDebounce() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self, sleeper] in
      do {
        try await sleeper.sleep(for: .debounce)
        await self?.fireDebounce()
      } catch is CancellationError {
        return
      } catch {
        await self?.setError(error)
      }
    }
  }

  func fireDebounce() {
    for root in pendingFullRoots { enqueueAutomatic(root: root, scope: .full) }
    for (root, paths) in pendingPaths where !pendingFullRoots.contains(root) {
      enqueueAutomatic(root: root, scope: .paths(paths))
    }
    pendingFullRoots = []
    pendingPaths = [:]
    debounceTask = nil
  }

  func enqueueFullReconciliation() {
    for root in roots { enqueueAutomatic(root: root, scope: .full) }
  }

  func enqueue(_ request: ScanRequest) {
    requestQueue.append(request)
    guard !isDraining else { return }
    isDraining = true
    Task { [weak self] in await self?.drainQueue() }
  }

  func drainQueue() async {
    while !requestQueue.isEmpty {
      let request = requestQueue.removeFirst()
      do {
        let result = try await scanService.scan(request)
        scheduleRecheck(root: request.root, identities: result.pendingIdentities)
      } catch is CancellationError {
        break
      } catch {
        lastError = String(describing: error)
      }
    }
    isDraining = false
  }

  func scheduleRecheck(root: URL, identities: Set<FileIdentity>) {
    recheckTasks[root]?.cancel()
    guard !identities.isEmpty, !isPaused else {
      recheckTasks[root] = nil
      return
    }
    recheckTasks[root] = Task { [weak self, sleeper] in
      do {
        try await sleeper.sleep(for: .pendingRecheck)
        await self?.enqueueAutomatic(root: root, scope: .candidates(identities))
      } catch {
        return
      }
    }
  }

  func scheduleReconciliation() {
    reconciliationTask?.cancel()
    reconciliationTask = Task { [weak self, sleeper] in
      do {
        while !Task.isCancelled {
          try await sleeper.sleep(for: .reconciliation)
          await self?.enqueueFullReconciliation()
        }
      } catch {
        return
      }
    }
  }

  func setError(_ error: Error) {
    lastError = String(describing: error)
  }
}
