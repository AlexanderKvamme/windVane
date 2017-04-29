

import UIKit
import CoreLocation
import Spring
import GoogleMaps

/*Runs two fetches from  yr and from darksky.. Darksky is less accurate, so after the darksky data is modelled, replaceDarkSkyHourDataWithAvailableHourFromYr() is run to update the first 48 hours with more accurate values, and some additional values such as isChanceOfPrecipitation*/

var midScreen = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)

class MainMenuViewController: UIViewController, CLLocationManagerDelegate {

    //MARK: - Properties
    var yrClient = YrClient()
    
    @IBOutlet weak var animationStack: UIView! // checkmark animation and activity indicator
    @IBOutlet weak var mainButton: UIButton!
    @IBOutlet weak var buttonStack: UIStackView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var checkmarkView: UIImageView!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var shakeToRefreshImage: UIImageView!
    @IBOutlet weak var enableGPSImage: UIImageView!
    @IBAction func unwindToMainMenu(segue: UIStoryboardSegue) {}
    
    var mapView: GMSMapView!
    var buttonOutline = UIView()
    
    var isFetching = false
    var mainButtonWidth: CGFloat = 100
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMainButton()

        GMSServices.provideAPIKey("AIzaSyD18MznE0DNTMCWnTQNVWaYxHUZ8ClXDGE")
        
        setUserDefaultsIfInitialRun()
        buttonStack.isUserInteractionEnabled = false
        activityIndicator.isUserInteractionEnabled = false
        checkmarkView.isUserInteractionEnabled = false
        animationStack.isUserInteractionEnabled = false
        
        if UserDefaults.standard.bool(forKey: "willAllowLocationServices"){
            toggleLoadingMode(true)
            UserLocation.sharedInstance.updateLocation()
        } else {
            isFetching = false
            toggleLoadingMode(true)
            shakeToRefreshImage.isHidden = false
            enableGPSImage.isHidden = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        setObservers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        UIApplication.shared.keyWindow?.rootViewController = self // Stops unwind from "TODAY" from unwinding further back, to Onboarding
    }
    
    // MARK: - motionBegan
    
    override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
        if UserDefaults.standard.bool(forKey: "willAllowLocationServices") && isFetching == false {
            toggleLoadingMode(true)
            UserLocation.sharedInstance.updateLocation() // this will then fetch new weather after gps update
        } else {
            let missingLocationServicesAlert = UIAlertController(title: "Location Services needed", message: "In order to provide you with the latest local weather, you need to give us access to your location!", preferredStyle: UIAlertControllerStyle.alert)
            missingLocationServicesAlert.addAction(UIAlertAction(title: "No thanks", style: UIAlertActionStyle.cancel, handler: nil))
            missingLocationServicesAlert.addAction(UIAlertAction(title: "Allow", style: UIAlertActionStyle.default, handler: { (UIAlertAction) in
                UserDefaults.standard.setValue(true, forKey: "willAllowLocationServices")
                UserDefaults.standard.synchronize()
                UserLocation.sharedInstance.updateLocation()
            }))
            present(missingLocationServicesAlert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Helper Methods

    func fetchWeather(){
        guard let currentCoordinate = currentCoordinate else {
            return
        }
        forecastClient.fetchExtendedCurrentWeather(forCoordinate: currentCoordinate) { apiresult in
            self.toggleLoadingMode(false)
            
            switch apiresult{
            case .success(let result):
                
                // update global variable
                latestExtendedWeatherFetch.currentWeather = result.currentWeather
                latestExtendedWeatherFetch.dailyWeather = result.dailyWeather
                latestExtendedWeatherFetch.hourlyWeather = result.hourlyWeather
                
                self.replaceDarkSkyHourDataWithAvailableHourFromYr()
                
                if let
                    fetchedDays = latestExtendedWeatherFetch.dailyWeather,
                    let fetchedHours = latestExtendedWeatherFetch.hourlyWeather {
                    
                    var dayIndex = 0
                    var organizedHours = [HourData]()
                    for hour in fetchedHours where dayIndex < fetchedDays.count {
                        if hour.dayNumber == fetchedDays[dayIndex].dayNumber {
                            organizedHours.append(hour)
                        } else{
                            latestExtendedWeatherFetch.dailyWeather![dayIndex].hourData = organizedHours
                            organizedHours.removeAll()
                            dayIndex += 1
                        }
                    }
                }
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: NotificationNames.fetchCurrentWeatherDidFinish), object: self)
                
            case .failure(let error as NSError):
                self.toggleLoadingMode(true)
                showAlert(viewController: self, title: "Error fetching data", message: "Could not update weather data. Error: \(error.localizedDescription). \n\n Check your internet connection", error: error)
            default: break
            }
        }
    }
    
    func replaceDarkSkyHourDataWithAvailableHourFromYr() {
        // The first 48 hours are available from yr and are much more accurate than DarkSky, so here the first hours from Darksky are replaced with the avaiable hourData from yr. (The first 48 hours). Replaces temperatures and precipitation
        guard let yrHours = latestExtendedWeatherFetch.hourlyWeatherFromYr else {
            print("ERROR: no yrHours stored in global value 'latestExtendedWeatherFetch'.")
            return
        }

        for i in 0 ..< yrHours.count {
            if hourHasPrecipitation(yrHours[i]) {
                    latestExtendedWeatherFetch.hourlyWeather?[i].isChanceOfPrecipitation = true
            }
            
            latestExtendedWeatherFetch.hourlyWeather?[i].temperature = (latestExtendedWeatherFetch.hourlyWeatherFromYr?[i].temperature)!
        }
    }
    
    func hourHasPrecipitation(_ hour: YrHourData) -> Bool {
        
        if hour.precipitationMinValue != nil && hour.precipitationMaxValue != nil {
            return true
        }
        return false
    }
    
    func fetchWeatherFromYr(){
        // This is run from the reverseGeocodeHandler after updating self.currentLocation so the location data is available in the UserLocation singleton
        // Format reverseGeocode location to a XML request and send to yr.no
        
        let country = UserLocation.sharedInstance.country
        let adminArea = UserLocation.sharedInstance.administrativeArea
        let locality = UserLocation.sharedInstance.locality
        let subLocality = UserLocation.sharedInstance.subLocality
        
        let urlString = "http://www.yr.no/place/\(country)/\(adminArea)/\(locality)/\(subLocality)/forecast_hour_by_hour.xml"

        yrClient.fetchHourlyDataFromYr(URL: urlString) { (result) in
            switch result {
            case .Success(let resultingYrData):
                
                latestExtendedWeatherFetch.hourlyWeatherFromYr = resultingYrData // update global value (to let Charts access it)
                
                // post notifications
                  NotificationCenter.default.post(name: Notification.Name(rawValue: NotificationNames.userLocationGPSDidUpdate), object: self)
                  NotificationCenter.default.post(name: Notification.Name(rawValue: NotificationNames.fetchWeatherFromYrDidFinish), object: self)

            case .Failure(let e):
                print("i got back failure with e: \(e)")
                NotificationCenter.default.post(name: Notification.Name(rawValue: NotificationNames.fetchWeatherFromYrFailed), object: self)
            }
        }
    }
    
    private func toggleLoadingMode(_ status: Bool){
        switch status{
        case true:
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut , animations: {
                
                // animated fade in of label, and fade in of text
                self.mainButton.titleLabel?.alpha = 0
                self.mainButton.alpha = 0
                //self.mainButton.transform = CGAffineTransform.init(scaleX: 0.5, y: 0.5)
                self.mainButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
                self.mainButton.layer.cornerRadius = 25
                //self.mainButton.backgroundColor = .white
            }, completion: { (_) in
//                self.mainButton.transform = CGAffineTransform.init(scaleX: 1, y: 1)
            })

            self.animateButtonOutline(visible: true)
            self.isFetching = true
            self.activityIndicator.startAnimating()
            self.activityIndicator.isHidden = false
            self.mainButton.backgroundColor = .white
            self.settingsButton.alpha = 0.4
            self.buttonStack.isUserInteractionEnabled = false
            self.settingsButton.isUserInteractionEnabled = false
            
        case false:
            UIView.animate(withDuration: 0.5,
                           delay: 1,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.5,
                           options: .curveEaseInOut ,
                           animations: {
                            self.mainButton.alpha = 1
                            //self.mainButton.transform = CGAffineTransform.init(scaleX: 1, y: 1)
                            self.mainButton.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                            self.mainButton.layer.cornerRadius = 50
                //self.mainButton.backgroundColor = .white
            }, completion: { (_) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.mainButton.titleLabel?.alpha = 1
                })
                
                //                self.mainButton.transform = CGAffineTransform.init(scaleX: 1, y: 1)
            })
            self.animateButtonOutline(visible: false)
            self.isFetching = false
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            //self.buttonStack.alpha = 1
            self.mainButton.backgroundColor = .black
            self.settingsButton.alpha = 1
            self.buttonStack.isUserInteractionEnabled = true
            self.settingsButton.isUserInteractionEnabled = true
            Animations.playCheckmarkAnimationOnce(inImageView: self.checkmarkView)
            self.view.bringSubview(toFront: self.mainButton)
        }
    }
    
    func setObservers(){
        // Location based
        NotificationCenter.default.addObserver(self, selector: #selector(locationManagerFailedHandler), name: NSNotification.Name(rawValue: NotificationNames.locationManagerFailed), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reverseGeocodeFinishedHandler), name: NSNotification.Name(rawValue: NotificationNames.reverseGeocodingDidFinish), object: nil)
        
        // Networking
        NotificationCenter.default.addObserver(self, selector: #selector(fetchDidFinishHandler), name: NSNotification.Name(rawValue: NotificationNames.fetchCurrentWeatherDidFinish), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchFromDarkSkyFailed), name: NSNotification.Name(rawValue: NotificationNames.fetchCurrentWeatherDidFail), object: nil)
        
        // Yr
        NotificationCenter.default.addObserver(self, selector: #selector(fetchWeatherFromYrDidFinishHandler), name: NSNotification.Name(rawValue: NotificationNames.fetchWeatherFromYrDidFinish), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchWeatherFromYrFailedHandler), name: NSNotification.Name(rawValue: NotificationNames.fetchWeatherFromYrFailed), object: nil)

        // System
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidUpdate), name: NSNotification.Name(rawValue: NotificationNames.settingsDidUpdate), object: nil)
    }
    
    // MARK: - Handlers for observers
    func fetchWeatherFromYrDidFinishHandler(){
        //print("finished fetching hour data from Yr handler")
    }
    
    func fetchWeatherFromYrFailedHandler(){
        print("Failed fetching hours from Yr")
    }
    
    func fetchFromDarkSkyFailed() {
        if self.presentedViewController == nil {
            showAlert(viewController: self, title: "Server denied fetch", message: "Please try again later", error: nil)
        }
    }
    
    func fetchDidFinishHandler(){
        self.shakeToRefreshImage.isHidden = true
        self.enableGPSImage.isHidden = true
    }

    func locationManagerFailedHandler(){
        self.enableGPSImage.isHidden = false
    }
    
    func settingsDidUpdate(){
        self.activityIndicator.isHidden = false
        self.activityIndicator.startAnimating()
        fetchWeather()
    }

    func reverseGeocodeFinishedHandler(){
        if let latestGPS = UserLocation.sharedInstance.coordinate{
            currentCoordinate = latestGPS
            fetchWeather()
            fetchWeatherFromYr()
            showMap(atCoordinate: currentCoordinate!)
            // FIXME: - move into fetchWeather when finished
            // Dette er inni reverseGeocodeHandler, så dette er ETTER vi har returnert resultat. Vi har en
        } else {
            showAlert(viewController: self, title: "Error fetching gps", message: "We can fetch weather for you if you let us access Location Services. Please enable Location Services in your settings and restart the app to update GPS.", error: nil)
        }
    }
    private func showMap(atCoordinate coordinate: Coordinate) {
        let screenWidth = UIScreen.main.bounds.size.width
        let screenHeight = UIScreen.main.bounds.size.height
        let userLocation = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let camera = GMSCameraPosition.camera(withTarget: userLocation, zoom: 11)
        let mapFrame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        mapView = GMSMapView.map(withFrame: mapFrame, camera: camera)
        
        // style
        
        do {
            // Set the map style by passing the URL of the local file.
            if let styleURL = Bundle.main.url(forResource: "mapStyle", withExtension: "json") {
                mapView.mapStyle = try GMSMapStyle(contentsOfFileURL: styleURL)
            } else {
                NSLog("Unable to find style.json")
            }
        } catch {
            NSLog("One or more of the map styles failed to load. \(error)")
        }
        mapView.isUserInteractionEnabled = false
        mapView.alpha = 0
        
        view.addSubview(mapView)
        view.sendSubview(toBack: mapView)
        
        UIView.animate(withDuration: 5, animations: {
            self.mapView.alpha = 1
            self.mapView.animate(toZoom: 13)
        }, completion: nil)
    }
    
    private func setupMainButton() {
        mainButton.setTitleColor(.white, for: .normal)
        mainButton.setTitle("GO", for: .normal)
        var pos = mainButton.frame
        let buttonRect = CGRect(x: pos.minX, y: pos.minY, width: mainButtonWidth, height: mainButtonWidth)
        mainButton.frame = buttonRect
        mainButton.backgroundColor = .black
        mainButton.layer.cornerRadius = 50
        mainButton.translatesAutoresizingMaskIntoConstraints = true
        mainButton.setNeedsLayout()
        mainButton.titleLabel?.alpha = 0
        
        setupAnimationStack()
        makeOutlineViewAroundButton()
    }
    
    private func setupAnimationStack() {
        let frameWidth: CGFloat = 40
        let xPos = view.frame.midX - frameWidth/2
        let yPos = view.frame.midY - frameWidth/2
        // activityIndicator.color = .white
        
        // Move stack to center
        animationStack.frame = CGRect(x: xPos, y: yPos, width: frameWidth, height: frameWidth)
        animationStack.translatesAutoresizingMaskIntoConstraints = true
    }
    
    func makeOutlineViewAroundButton() {
        let outlineWidth: CGFloat = mainButton.frame.width + 20
        let circleCornerRadius = outlineWidth / 2
        
        buttonOutline = UIView(frame: CGRect(x: view.frame.midX - outlineWidth/2,
                                             y: view.frame.midY - outlineWidth/2,
                                             width: outlineWidth,
                                             height: outlineWidth))
        
        buttonOutline.layer.cornerRadius = circleCornerRadius
        buttonOutline.layer.borderColor = UIColor.black.cgColor
        buttonOutline.layer.borderWidth = 5
        buttonOutline.isUserInteractionEnabled = false
        buttonOutline.alpha = 0
        view.addSubview(buttonOutline)
        view.bringSubview(toFront: buttonOutline)
    }
    
    private func animateButtonOutline(visible: Bool) {
        let duration = 0.3
        switch visible {
        case true:
            UIView.animate(withDuration: duration, animations: { 
                self.buttonOutline.transform = CGAffineTransform.init(scaleX: 0.5, y: 0.5)
                //self.buttonOutline.alpha = 0
            }, completion: { (_) in
                //
            })
        case false:
            UIView.animate(withDuration: duration, delay: 1, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                self.buttonOutline.transform = CGAffineTransform.init(scaleX: 1, y: 1)
                self.buttonOutline.alpha = 1
            })
        }
    }

// MARK: - Helper methods

    func setUserDefaultsIfInitialRun(){
        let currentPreferredUnits = UserDefaults.standard.string(forKey: "preferredUnits")
        if currentPreferredUnits == nil {
            UserDefaults.standard.set("SI", forKey: "preferredUnits")
        }
    }
}
