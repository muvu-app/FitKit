import Flutter
import UIKit
import HealthKit

public class SwiftFitKitPlugin: NSObject, FlutterPlugin {

    private let TAG = "FitKit";

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fit_kit", binaryMessenger: registrar.messenger())
        let instance = SwiftFitKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var healthStore: HKHealthStore? = nil;

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: TAG, message: "Not supported", details: nil))
            return
        }

        if (healthStore == nil) {
            healthStore = HKHealthStore();
        }

        do {
            if (call.method == "hasPermissions") {
                let request = try PermissionsRequest.fromCall(call: call)
                hasPermissions(request: request, result: result)
            } else if (call.method == "requestPermissions") {
                let request = try PermissionsRequest.fromCall(call: call)
                requestPermissions(request: request, result: result)
            } else if (call.method == "revokePermissions") {
                revokePermissions(result: result)
            } else if (call.method == "read") {
                let request = try ReadRequest.fromCall(call: call)
                read(request: request, result: result)
            } else if (call.method == "isAuthorized") {
                do {
                    isAuthorized(result: result)
                } catch {
                    result(FlutterError(code: TAG, message: "Error \(error)", details: nil))
                }
            } else if (call.method == "readDay") {
                do {
                    let request = try ReadRequest.fromCall(call: call)
                    readDay(request: request, result: result)
                } catch {
                    result(FlutterError(code: TAG, message: "Error \(error)", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: TAG, message: "Error \(error)", details: nil))
        }
    }


    /**
    * On iOS you can only know if user has responded to request access screen.
    * Not possible to tell if he has allowed access to read.
    *
    *   # getRequestStatusForAuthorization #
    *   If "status == unnecessary" means if requestAuthorization will be called request access screen will not be shown.
    *   So user has already responded to request access screen and kinda has permissions.
    *
    *   # authorizationStatus #
    *   If "status == notDetermined" user has not responded to request access screen.
    *   Once he responds no matter of the result status will be sharingDenied.
    */
    private func hasPermissions(request: PermissionsRequest, result: @escaping FlutterResult) {
        if #available(iOS 12.0, *) {
            healthStore!.getRequestStatusForAuthorization(toShare: [], read: Set(request.sampleTypes)) { (status, error) in
                guard error == nil else {
                    result(FlutterError(code: self.TAG, message: "hasPermissions", details: error))
                    return
                }

                guard status == HKAuthorizationRequestStatus.unnecessary else {
                    result(false)
                    return
                }

                result(true)
            }
        } else {
            let authorized = request.sampleTypes.map {
                        healthStore!.authorizationStatus(for: $0)
                    }
                    .allSatisfy {
                        $0 != HKAuthorizationStatus.notDetermined
                    }
            result(authorized)
        }
    }

    private func isAuthorized(result: @escaping FlutterResult) {
        if (healthStore == nil) {
            healthStore = HKHealthStore();
        }
        let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
        let authorizationStatus = healthStore!.authorizationStatus(for: type!)

        switch authorizationStatus {
        case .sharingAuthorized:
            result(true)
        case .sharingDenied:
            result(true)
        default:
            result(false)
        }
    }

    private func requestPermissions(request: PermissionsRequest, result: @escaping FlutterResult) {
        requestAuthorization(sampleTypes: request.sampleTypes) { success, error in
            guard success else {
                result(false)
                return
            }

            result(true)
        }
    }

    /**
    * Not supported by HealthKit.
    */
    private func revokePermissions(result: @escaping FlutterResult) {
        result(nil)
    }

    private func read(request: ReadRequest, result: @escaping FlutterResult) {
        requestAuthorization(sampleTypes: [request.sampleType]) { success, error in
            guard success else {
                result(error)
                return
            }

            self.readSample(request: request, result: result)
        }
    }

    private func readDay(request: ReadRequest, result: @escaping FlutterResult) {
        requestAuthorization(sampleTypes: [request.sampleType]) { success, error in
            guard success else {
                result(error)
                return
            }

            self.readDailySample(request: request, result: result)
        }
    }

    private func requestAuthorization(sampleTypes: Array<HKSampleType>, completion: @escaping (Bool, FlutterError?) -> Void) {
        healthStore!.requestAuthorization(toShare: nil, read: Set(sampleTypes)) { (success, error) in
            guard success else {
                completion(false, FlutterError(code: self.TAG, message: "Error \(error?.localizedDescription ?? "empty")", details: nil))
                return
            }

            completion(true, nil)
        }
    }

    private func readDailySample(request: ReadRequest, result: @escaping FlutterResult) {
        var identifier = HKQuantityTypeIdentifier.stepCount
        var unit = HKUnit.count();
        let now = Date()
        if (request.type == "energy") {
            identifier = HKQuantityTypeIdentifier.activeEnergyBurned
            unit = HKUnit.kilocalorie()
        } else if (request.type == "distance_cycling") {
            identifier = HKQuantityTypeIdentifier.distanceCycling
            unit = HKUnit.meter()
        } else if (request.type == "distance") {
            identifier = HKQuantityTypeIdentifier.distanceWalkingRunning
            unit = HKUnit.meter()
        }

        let type = HKSampleType.quantityType(forIdentifier: identifier)

        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        var interval = DateComponents()
        interval.day = 1
        var anchorComponents = Calendar.current.dateComponents([.day, .month, .year], from: now)
        anchorComponents.hour = 0
        let anchorDate = Calendar.current.date(from: anchorComponents)!

        let datePredicate = HKQuery.predicateForSamples(withStart:startDate,end:now,options:.strictStartDate)
        let manualPredicate = NSPredicate(format:"metadata.%K != YES",HKMetadataKeyWasUserEntered)
        let compoundPredicate = NSCompoundPredicate(type:.and,subpredicates:[datePredicate,manualPredicate])
        let query = HKStatisticsCollectionQuery(quantityType: type!,
                                        quantitySamplePredicate: compoundPredicate,
                                        options: [.cumulativeSum],
                                        anchorDate: anchorDate,
                                        intervalComponents: interval)

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                // log.error("Error returned form resultHandler = \(String(describing: error?.localizedDescription))")
                return
            }

            var response: NSArray = []
            results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let values = sum.doubleValue(for: unit)
                    let dict: NSDictionary = ["value": values, "date": formatter.string(from: statistics.startDate)]
                    response = response.adding(dict) as NSArray
                }
            }
            // print("readSample: \(response)")
            result(response)
        }

        healthStore!.execute(query)
    }

    private func readSample(request: ReadRequest, result: @escaping FlutterResult) {
        print("readSample: \(request.type)")

        let predicate = HKQuery.predicateForSamples(withStart: request.dateFrom, end: request.dateTo, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: request.limit == nil)

        let query = HKSampleQuery(sampleType: request.sampleType, predicate: predicate, limit: request.limit ?? HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
            _, samplesOrNil, error in

            guard var samples = samplesOrNil else {
                result(FlutterError(code: self.TAG, message: "Results are null", details: error))
                return
            }

            if (request.limit != nil) {
                // if limit is used sort back to ascending
                samples = samples.sorted(by: { $0.startDate.compare($1.startDate) == .orderedAscending })
            }

            print(samples)
            result(samples.map { sample -> NSDictionary in
                [
                    "value": self.readValue(sample: sample, unit: request.unit),
                    "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                    "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                    "source": self.readSource(sample: sample),
                    "user_entered": sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true
                ]
            })
        }
        healthStore!.execute(query)
    }

    private func readValue(sample: HKSample, unit: HKUnit) -> Any {
        if let sample = sample as? HKQuantitySample {
            return sample.quantity.doubleValue(for: unit)
        } else if let sample = sample as? HKCategorySample {
            return sample.value
        }

        return -1
    }

    private func readSource(sample: HKSample) -> String {
        if #available(iOS 9, *) {
            return sample.sourceRevision.source.name;
        }

        return sample.source.name;
    }
}
