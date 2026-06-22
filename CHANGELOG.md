# Changelog

## [0.7.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.6.0...v0.7.0) (2026-06-22)


### Features

* **attest-image:** replace old dedicated actions by unified new attest action ([889c417](https://github.com/dnum-mi/fabnum-cicd/commit/889c4179688e22e1d77dded27410a91720c4add7))


### Dependencies

* **workflows:** upgrade actions versions ([eb7136c](https://github.com/dnum-mi/fabnum-cicd/commit/eb7136cb583ad1eb4033112e167c41caafe10904))

## [0.6.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.5.1...v0.6.0) (2026-05-22)


### Features

* **update-helm-chart:** add local run mode for release-please branch ([dd3a217](https://github.com/dnum-mi/fabnum-cicd/commit/dd3a2176c7bdc52da3281726834bd6a76aa27f10))


### Bug Fixes

* **build-docker:** fix artifact names and skip merge when PUSH_IMAGE=false ([0eeb282](https://github.com/dnum-mi/fabnum-cicd/commit/0eeb282cbb51e700269ef60cb498728c096a5424))
* **build-docker:** make multi-arch runners and platforms explicit ([0f181ba](https://github.com/dnum-mi/fabnum-cicd/commit/0f181ba68c7d41d5a3099d1e6ff971a7a475791f))

## [0.5.1](https://github.com/dnum-mi/fabnum-cicd/compare/v0.5.0...v0.5.1) (2026-05-21)


### Bug Fixes

* **build-docker:** re-enable registry login even without push ([871a861](https://github.com/dnum-mi/fabnum-cicd/commit/871a86185083af421cd33f53415129996c826f09))

## [0.5.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.4.0...v0.5.0) (2026-05-21)


### Features

* **build-docker:** add PUSH_IMAGE input to conditionally push Docker images ([aa1699f](https://github.com/dnum-mi/fabnum-cicd/commit/aa1699f301f2b13e2b1a423c552d893e4548dd66))

## [0.4.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.3.0...v0.4.0) (2026-03-12)


### Features

* **update-helm-chart:** handle auto-merge in called mode ([ac8113f](https://github.com/dnum-mi/fabnum-cicd/commit/ac8113f6ffa3fb52a0a01ae10c86ba530fc1f68d))

## [0.3.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.2.0...v0.3.0) (2026-03-10)


### Features

* **build-docker:** split workflow with dedicated attestation workflow ([dcceedd](https://github.com/dnum-mi/fabnum-cicd/commit/dcceeddb2e015d88466237eacec5f13bcca007e1))
* improve security by passing sensitive data as secrets ([446ca8a](https://github.com/dnum-mi/fabnum-cicd/commit/446ca8abb69e09c2a784c2599e944d0128caa569))

## [0.2.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.1.1...v0.2.0) (2026-03-10)


### Features

* scope permissions by job ([3f7a680](https://github.com/dnum-mi/fabnum-cicd/commit/3f7a6802dd3dfaa2947938aaa45b40da35a8f025))

## [0.1.1](https://github.com/dnum-mi/fabnum-cicd/compare/v0.1.0...v0.1.1) (2026-03-10)


### Code Refactoring

* **workflows:** pin actions versions and improve some workflows ([0a0c47d](https://github.com/dnum-mi/fabnum-cicd/commit/0a0c47db85dd35260ecb037946850bacbab441de))

## [0.1.0](https://github.com/dnum-mi/fabnum-cicd/compare/v0.0.1...v0.1.0) (2026-03-05)


### Features

* add git hooks ([632ea6f](https://github.com/dnum-mi/fabnum-cicd/commit/632ea6f74834c347a7b4ca342c6c61f05bf90673))
* add more workflows ([a6d5070](https://github.com/dnum-mi/fabnum-cicd/commit/a6d50704592c3a33ef29e3d5a76c64b39b999f01))
* add sonarqube scan workflow ([1a334a3](https://github.com/dnum-mi/fabnum-cicd/commit/1a334a3c02fde67410c7921bd1c009ba737cbbbc))
* add trivy scan workflow ([bcfebb7](https://github.com/dnum-mi/fabnum-cicd/commit/bcfebb71d9411159f30868ac824849597eb2e082))
* **lint-commits:** add new workflow ([ceb7e16](https://github.com/dnum-mi/fabnum-cicd/commit/ceb7e162691af727d8a823c47283942d692bf7c3))
* **lint-helm-schema:** introduce workflow to lint helm schema file ([7d28e32](https://github.com/dnum-mi/fabnum-cicd/commit/7d28e327068d3dca480a77e5f7e39f12e01307e7))
* **lint-yaml:** introduce workflow to lint yaml files ([59d6dae](https://github.com/dnum-mi/fabnum-cicd/commit/59d6daebfde7a371e14c13b01314be59ef64097b))
* **release-app:** handle additional files to upload in release ([e5d7d49](https://github.com/dnum-mi/fabnum-cicd/commit/e5d7d490db5f9a843307d39023ead63f8c325355))
* **scan-sonarqube:** add fail on error option ([d6d8167](https://github.com/dnum-mi/fabnum-cicd/commit/d6d81677edfd1036e37e0b121ba2355a0a8a4d82))
* **sync-cpin:** add sync all branches option ([b1482f4](https://github.com/dnum-mi/fabnum-cicd/commit/b1482f4963f7d5939037db8497a74806deb5bbeb))
* **update-helm-chart:** handle different chart directory ([7af4c15](https://github.com/dnum-mi/fabnum-cicd/commit/7af4c15d2fb924f77c033ee7a8596f7a672b7973))
* **update-helm-chart:** handle multiple prerelease identifiers ([284e2b9](https://github.com/dnum-mi/fabnum-cicd/commit/284e2b9f185e4e5d3262cecb9084f964eebda653))
* use ubuntu-24.04 as default runner and handle override ([49efa97](https://github.com/dnum-mi/fabnum-cicd/commit/49efa97738c97b387bf1eaea8a4f5f303a7a16b1))


### Bug Fixes

* **build-docker:** reword multi tag input for harmonization ([9fd7f97](https://github.com/dnum-mi/fabnum-cicd/commit/9fd7f973cb71779d6950a8ccf8a36b8eae3252b7))
* **clean-cache:** use simpler workflow ([e39d6d1](https://github.com/dnum-mi/fabnum-cicd/commit/e39d6d18a28434943baa44189e127cfa155615ce))
* **helm:** fetch main branch for ct to process diffs ([276a403](https://github.com/dnum-mi/fabnum-cicd/commit/276a403ae62e8a52544b52c341c9c4a50ab3a0df))
* output the full version of the release in release-app ([6e98990](https://github.com/dnum-mi/fabnum-cicd/commit/6e9899014b2a191ccb0799b6087aa95a43c6f508))
* **release-helm:** chart-releaser config ([a3ddcc0](https://github.com/dnum-mi/fabnum-cicd/commit/a3ddcc0268c32547be3ee170d11f9300e064457b))
* **release-helm:** update chart releaser config ([8d94627](https://github.com/dnum-mi/fabnum-cicd/commit/8d94627c54144cf3062ad8c1726c99a72356afe6))
* reusable workflows ([36108f9](https://github.com/dnum-mi/fabnum-cicd/commit/36108f9809d9da08cc22fb2d7bb6843d489ba0d0))
* reusable workflows configuration ([337a646](https://github.com/dnum-mi/fabnum-cicd/commit/337a646d2d1c7fc56c2d63653603ad70bb329743))
* **update-helm-chart:** fix semver process ([beb784b](https://github.com/dnum-mi/fabnum-cicd/commit/beb784b12c7ff9059bf5f83ddd4c2f7f7f69c3fd))
* **update-helm-chart:** improve pre-release strategy ([f95d608](https://github.com/dnum-mi/fabnum-cicd/commit/f95d60814cc2723853fc4dd247d49960ff91696e))
* **update-helm-chart:** remove prerelease identifier on release ([ed6ede0](https://github.com/dnum-mi/fabnum-cicd/commit/ed6ede01d5ec6a1754abfd79525a0e76ce64b1cc))
