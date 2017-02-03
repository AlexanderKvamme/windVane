//
//  TodayViewController.swift
//  ShortsDotCom
//
//  Created by Alexander Kvamme on 08/12/2016.
//  Copyright © 2016 Alexander Kvamme. All rights reserved.
//

import UIKit
import Charts

// FIXME: Gjør om til egen metode og send inn left or right for å unngå duplicate

class TodayViewController: UIViewController, ChartViewDelegate, UIGestureRecognizerDelegate{
    
    // MARK: - Outlets
    
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var summaryLabel: UILabel!
    @IBOutlet weak var stackHeader: UILabel!
    @IBOutlet weak var stack1Image: UIImageView!
    @IBOutlet weak var stack1Label: UILabel!
    @IBOutlet weak var stack2Image: UIImageView!
    @IBOutlet weak var stack2Label: UILabel!
    @IBOutlet weak var stack3Image: UIImageView!
    @IBOutlet weak var stack3Label: UILabel!
    @IBOutlet weak var iconStack: UIStackView!
    @IBOutlet weak var graphHeader: UILabel!
    
    var imageStack = [UIImageView]()
    var viewStack = [UIView]()
    
    // MARK: - Properties
    
    let combinedLineColor = UIColor.black //Dots and lines for the graph
    var temperatures : [Double] = []
    var shortenedTimestamps = [Double]()
    var timestamps: [Double] = []
    var dayIndex: Int = 0
    let maxSummaryLines = 3
    
    enum AnimationDirection{
        case left
        case right
    }
    
    var swipeAnimation: UIViewPropertyAnimator!
    var animateToXPos: CGPoint!
    var headerLabelPositionLeft: CGFloat!
    var headerLabelPositionRight: CGFloat!
    var headerLabelpositionX: CGFloat!
    var headerLabelPositionY: CGFloat!
    var animationDirection: AnimationDirection!
    var headerXShift: CGFloat = 10 // animation x-distance
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageStack = [self.stack1Image, self.stack2Image, self.stack3Image]
        viewStack = [self.dayLabel, self.dateLabel, self.weatherIcon, self.summaryLabel, self.stack2Image, self.iconStack, self.stack1Label, self.stack2Label, self.stack3Label]
        
        setUI()
        setHeaderAnimationDestination()
        displayDay(at: dayIndex)
        addSwipeAndPanRecognizers()
    }
    
    
    // MARK: - UI Setup
    
    func setUI(){
        stackHeader.alpha = 0.3
        graphHeader.alpha = 0.3
        stack3Image.image = UIImage(named: "weathercock.png")
        stack1Image.image = UIImage(named: "temperature.png")
    }
    
    func updateUIWith(day: DayData){
        dayLabel.text = day.dayName.uppercased()
        dateLabel.text = day.formattedDate
        weatherIcon.image = UIImage(named: day.weatherIcon.rawValue)
        summaryLabel.text = day.summary
        setLabel(label: summaryLabel, summary: day.summary)
        stack3Label.text = "\(Int(round(day.windSpeedInPreferredUnit.value))) + \(day.windSpeedInPreferredUnit.unit.symbol)"
        stack2Label.text = "\(day.precipProbability.asIntegerPercentage)%"
        stack2Image.image = UIImage(named: day.precipIcon.rawValue)
        
        guard let averageTemperature = day.averageTemperatureInPreferredUnit else {
            stack1Label.text = "Missing data"
            return
        }
        stack1Label.text = String(Int(round(averageTemperature.value))) + " " + averageTemperature.unit.symbol
    }

    // MARK: - Animation Methods
    
    // FIXME: - Clean up
    
    func moveViewsWithPan(gesture: UIPanGestureRecognizer){
        if (gesture.translation(in: view).y > 50 && abs(gesture.translation(in: view).x) < 50) && gesture.state == .ended{
            swipeDownHandler()
        }
        if gesture.state == .began {
            if gesture.velocity(in: view).x > 0{
                
                // if gesture.isleftPan(in: view)
                
                animationDirection = .left
                prepareAnimation(forDirection: .left)
                dayLabel.textAlignment = .left
            } else {
                animationDirection = .right
                prepareAnimation(forDirection: .right)
                dayLabel.textAlignment = .right
            }
            
            
            
            
        }
        swipeAnimation.fractionComplete = abs(gesture.translation(in: self.view).x/100)
        if gesture.state == .ended{
            dayLabel.textAlignment = .center
            if abs(gesture.translation(in: self.view).x) > 100{
                switch animationDirection!{
                case .left:
                    displayDay(at: dayIndex-1)
                case .right:
                    displayDay(at: dayIndex+1)
                }
                dayLabel.sizeToFit()
            }
            
            // if end of swipe, animate back to original position
            swipeAnimation.isReversed = true
            let v = gesture.velocity(in: view)
            let velocity = CGVector(dx: v.x / 200, dy: v.y / 200)
            let timingParameters = UISpringTimingParameters(mass: 200, stiffness: 50, damping: 100, initialVelocity: velocity)
            swipeAnimation.continueAnimation(withTimingParameters: timingParameters, durationFactor: 0.2)
        }
    }
    
    func slideUI(direction: AnimationDirection){
        let labelStack: [UILabel] = [self.stack1Label!, self.stack2Label!, self.stack3Label!]
        
        if direction == .left{
            slideComponents(.left)
            slideLabels(labelStack, direction: .left, additionalSlide: 5)
        }
        if direction == .right {
            slideComponents(.right)
            slideLabels(labelStack, direction: .right, additionalSlide: 5)
        }
    }
    
    func slideComponents(_ direction: AnimationDirection){
        let dayLabelPos = self.dayLabel.center.y
        let dateLabelYPos = self.dateLabel.center.y
        let dateLabelXShift: CGFloat = 20
        let iconRotationAmount: CGFloat = 0.05
        let iconDownscaleAmount: CGFloat = 0.75
        let iconTranslationAmount: CGFloat = 100
        let summaryYShift: CGFloat = -8
        let summaryXShift: CGFloat = 40
        let summaryRotation = -CGFloat.pi * 0.005
        let iconStackXShift: CGFloat = 10
        let iconStackYShift: CGFloat = 0
        let precipitationIconDownscaleAmount: CGFloat = 0.50
        
        switch direction{
        case .left:
            self.dayLabel.center = CGPoint(x: self.headerLabelPositionLeft, y: dayLabelPos)
            self.dateLabel.center = CGPoint(x: self.headerLabelPositionLeft + dateLabelXShift, y: dateLabelYPos)
            self.weatherIcon.transform = CGAffineTransform(rotationAngle: CGFloat.pi * -iconRotationAmount).scaledBy(x: iconDownscaleAmount, y: iconDownscaleAmount).translatedBy(x: iconTranslationAmount, y: 0)
            self.summaryLabel.transform = CGAffineTransform(translationX: summaryXShift, y: summaryYShift).rotated(by: summaryRotation)
            self.stack2Image.transform = CGAffineTransform(rotationAngle: CGFloat.pi * -iconRotationAmount).scaledBy(x: precipitationIconDownscaleAmount, y: precipitationIconDownscaleAmount)
            self.iconStack.transform = CGAffineTransform(translationX: iconStackXShift, y: iconStackYShift)
        case .right:
            self.dayLabel.center = CGPoint(x: self.headerLabelPositionRight, y: dayLabelPos)
            self.dateLabel.center = CGPoint(x: self.headerLabelPositionRight - dateLabelXShift, y: dateLabelYPos)
            self.weatherIcon.transform = CGAffineTransform(rotationAngle: CGFloat.pi * iconRotationAmount).scaledBy(x: iconDownscaleAmount, y: iconDownscaleAmount).translatedBy(x: -iconTranslationAmount, y: 0)
            self.summaryLabel.transform = CGAffineTransform(translationX: -summaryXShift, y: summaryYShift).rotated(by: -summaryRotation)
            self.iconStack.transform = CGAffineTransform(translationX: -iconStackXShift, y: iconStackYShift)
            self.stack2Image.transform = CGAffineTransform(rotationAngle: CGFloat.pi * iconRotationAmount).scaledBy(x: precipitationIconDownscaleAmount, y: precipitationIconDownscaleAmount)
        }
    }
    
    func slideLabels(_ labels: [UILabel], direction: AnimationDirection, additionalSlide: CGFloat){
        switch direction{
        case .right:
            for label in labels{
                let frame = label.frame
                label.frame = CGRect(x: frame.minX - additionalSlide, y: frame.minY, width: frame.width, height: frame.height)
            }
        case .left:
            for label in labels{
                let frame = label.frame
                label.frame = CGRect(x: frame.minX + additionalSlide, y: frame.minY, width: frame.width, height: frame.height)
            }
        }
    }
    
    func twistImages(_ images: [UIImageView], direction: AnimationDirection){
        let iconRotationAmount: CGFloat = 0.05
        let sideStackImageDownscaleAmount: CGFloat = 0.9
        let precipitationIconDownscaleAmount: CGFloat = 0.50
        switch direction{
        case .right:
            images[0].transform = CGAffineTransform(rotationAngle: CGFloat.pi * iconRotationAmount).scaledBy(x: sideStackImageDownscaleAmount, y: sideStackImageDownscaleAmount)
            images[1].transform = CGAffineTransform(rotationAngle: CGFloat.pi * iconRotationAmount).scaledBy(x: precipitationIconDownscaleAmount, y: precipitationIconDownscaleAmount)
            images[2].transform = CGAffineTransform(rotationAngle: CGFloat.pi * iconRotationAmount).scaledBy(x: sideStackImageDownscaleAmount, y: sideStackImageDownscaleAmount)
        case .left:
            images[0].transform = CGAffineTransform(rotationAngle: CGFloat.pi * -iconRotationAmount).scaledBy(x: sideStackImageDownscaleAmount, y: sideStackImageDownscaleAmount)
            images[1].transform = CGAffineTransform(rotationAngle: CGFloat.pi * -iconRotationAmount).scaledBy(x: precipitationIconDownscaleAmount, y: precipitationIconDownscaleAmount)
            images[2].transform = CGAffineTransform(rotationAngle: CGFloat.pi * -iconRotationAmount).scaledBy(x: sideStackImageDownscaleAmount, y: sideStackImageDownscaleAmount)
        }
    }
    
    func prepareAnimation(forDirection direction: AnimationDirection){
        self.swipeAnimation = UIViewPropertyAnimator(duration: 1, curve: .easeInOut) {
            
            if direction == .left{
                self.slideUI(direction: .left)
                self.twistImages(self.imageStack, direction: .left)
            }
            
            if direction == .right {
                self.slideUI(direction: .right)
                self.twistImages(self.imageStack, direction: .right)
            }
           self.fadeLabels()
        }
    }
    
    func fadeLabels(){
        self.dateLabel.alpha = 0
        self.summaryLabel.alpha = 0
        self.stack1Label.alpha = 0
        self.stack2Label.alpha = 0
        self.stack3Label.alpha = 0
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    // MARK: - Swipe Recognizers And Handlers
    
    func addSwipeAndPanRecognizers(){
        var swipeDownGestureRecognizer = UISwipeGestureRecognizer()
        swipeDownGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeDownHandler))
        swipeDownGestureRecognizer.direction = .down
        view.addGestureRecognizer(swipeDownGestureRecognizer)
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.moveViewsWithPan)))
    }
    
    func swipeDownHandler(){
        performSegue(withIdentifier: "unwindToMainMenu", sender: self)
    }
    
    
    // MARK: - Data Methods
    
    func displayDay(at requestedIndex: Int){
        if requestedIndex < 0  || requestedIndex > latestExtendedWeatherFetch!.dailyWeather!.count-1{// eller 2
            return
        }
        guard let requestedDay = latestExtendedWeatherFetch?.dailyWeather?[requestedIndex] else {
            return
        }
        updateChart(withDay: requestedIndex)
        updateUIWith(day: requestedDay)
        dayIndex = requestedIndex
    }
    
    // MARK: - Charts Methods
    
    func setChartLayout(){
        lineChartView.layer.borderColor = UIColor.black.cgColor
        lineChartView.layer.borderWidth = 0
        lineChartView.isUserInteractionEnabled = false
        lineChartView.animate(xAxisDuration: 0.5, yAxisDuration: 0.0)
        lineChartView.delegate = self
        lineChartView.chartDescription?.text = ""
        lineChartView.drawGridBackgroundEnabled = false
        lineChartView.drawBordersEnabled = false
        lineChartView.noDataText = "Not enough data provided"
        lineChartView.legend.enabled = false
        lineChartView.leftAxis.zeroLineColor = combinedLineColor
        lineChartView.leftAxis.axisLineWidth = 0
        lineChartView.leftAxis.drawLabelsEnabled = false
        lineChartView.leftAxis.drawAxisLineEnabled = false
        lineChartView.leftAxis.drawGridLinesEnabled = false
        lineChartView.leftAxis.granularityEnabled = true
        lineChartView.leftAxis.granularity = 2
        lineChartView.rightAxis.drawLabelsEnabled = false
        lineChartView.rightAxis.drawAxisLineEnabled = false
        lineChartView.rightAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.axisLineColor = .yellow
        lineChartView.xAxis.drawGridLinesEnabled = true // vertical lines
        lineChartView.xAxis.drawLabelsEnabled = true
        lineChartView.xAxis.drawAxisLineEnabled = false
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.axisMinimum = shortenedTimestamps[0]
        lineChartView.xAxis.granularity = 2
        lineChartView.setExtraOffsets(left: 20, top: 0, right: 20, bottom: 10)
        //self.lineChartView.chartDescription?.text = "Temperatures this day in INSERT UNIT TYPE"
    }
    
    func setChartData() {
        for timestamp in timestamps{
            shortenedTimestamps.append(shortenTimestamp(timestamp))
        }
        var valuesToGraph: [ChartDataEntry] = [ChartDataEntry]()
        
        for i in 0 ..< temperatures.count {
            valuesToGraph.append(ChartDataEntry(x: shortenedTimestamps[i], y: temperatures[i]))
        }
        
        let hourBasedFormatter = TimeStampFormatter()
        let xAxis = XAxis()
        xAxis.valueFormatter = hourBasedFormatter
        lineChartView.xAxis.valueFormatter = hourBasedFormatter
        
        for i in 0 ... (timestamps.count-1){
            shortenedTimestamps.append(shortenTimestamp(timestamps[i]))
        }
        
        let set1: LineChartDataSet = LineChartDataSet(values: valuesToGraph, label: nil)
        set1.axisDependency = .left
        set1.setColor(combinedLineColor)
        set1.setCircleColor(combinedLineColor)
        set1.lineWidth = 2.0
        set1.circleRadius = 4.0
        set1.fillAlpha = 65 / 255.0
        set1.fillColor = combinedLineColor
        set1.highlightColor = .white
        set1.highlightEnabled = false
        set1.drawCircleHoleEnabled = true
        set1.circleHoleRadius = 2.0
        
        // FIXME: - Funker korrekt når jeg displayer første dag ved loading, med" not enough data provided", men når jeg swipe til neste, og så tilbake, så vil den ikke vise dagen i det hele tatt
//        print("set1 entry count: ", set1.entryCount)
//        if set1.entryCount == 1 { return }

        let format = NumberFormatter()
        format.generatesDecimalNumbers = false
        let formatter = DefaultValueFormatter(formatter:format)
        lineChartView.lineData?.setValueFormatter(formatter)
        set1.valueFormatter = formatter
        var dataSets = [LineChartDataSet]()
        dataSets.append(set1)
        let data: LineChartData = LineChartData(dataSets: dataSets)
        data.setValueTextColor(.black)
        self.lineChartView.data = data
        print("set1: ", set1)
    }
    
    func getChartData(forDay requestedDay: Int){
        if let hours = latestExtendedWeatherFetch?.dailyWeather?[requestedDay].hourData{
            var temperatureArray: [Double] = []
            var timestampArray: [Double] = []
            var shortenedTimestampArray: [Double] = []
            
            for hour in hours{
                if hour.temperature >= -0.5 && hour.temperature <= 0{
                    temperatureArray.append(0)
                } else{
                    temperatureArray.append(hour.temperature)
                }
                timestampArray.append(hour.time)
                shortenedTimestampArray.append(shortenTimestamp(hour.time))
                if shortenTimestamp(hour.time) == 0{
                    break // End of day reached
                }
            }
            temperatures = temperatureArray
            timestamps = timestampArray
            shortenedTimestamps = shortenedTimestampArray
        } else {
            // send new extendedDataRequest or wait for the previous one to finish
        }
    }
    
    func updateChart(withDay day: Int){
        getChartData(forDay: day)
        setChartData()
        setChartLayout()
    }
    
    // MARK: - Helper Methods
    
    // Animation methods
    
    func setHeaderAnimationDestination(){
        headerLabelPositionLeft = dayLabel.frame.midX + headerXShift
        headerLabelPositionRight = dayLabel.frame.midX - headerXShift
        headerLabelPositionY = dayLabel.frame.midY
        headerLabelpositionX = dayLabel.frame.midX
    }
    
    // Typography methods
    
    func setLabel(label: UILabel, summary: String){
        label.text = "Placeholder to establish lineheight"
        label.numberOfLines = 1
        label.sizeToFitHeight()
        label.text = summary
        while label.willBeTruncated(){
            label.numberOfLines += 1
            label.text = balanceTextAlignment(summary, overLines: summaryLabel.numberOfLines)
            label.sizeToFitHeight()
        }
        if label.numberOfLines > maxSummaryLines{
            label.text = summary // no balance needed
        }
    }
    
    func balanceTextAlignment(_ text: String, overLines: Int) -> String {
        var i = [Int]()
        var x = [Int]()
        var chars = Array(text.characters)
        for index in 0..<overLines-1{
            i.append(chars.count/overLines * (index+1))
            x.append(chars.count/overLines * (index+1))
        }
        for index in (0..<i.count).reversed(){
            while chars[i[index]] != " " && chars[x[index]] != " " {
                i[index] -= 1
                x[index] += 1
            }
            if chars[i[index]] == " " {
                chars.insert("\n", at: i[index]+1)
            } else {
                chars.insert("\n", at: x[index]+1)
            }
        }
        return String(chars)
    }
    
    func shortenTimestamp(_ value: Double) -> Double {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .long
        let date: Date = Date(timeIntervalSince1970: value)
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        let newNumber: Double = Double(hour) * 100 + Double(minute)
        return newNumber
    }
    
    // MARK: Motion Began
    
    override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
        viewDidLoad()
    }
    
}
