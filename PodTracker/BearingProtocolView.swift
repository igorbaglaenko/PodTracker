//
//  BearingProtocolView.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-07-06.
//

import SwiftUI

struct BearingProtocolView: View {
    @EnvironmentObject var podData: PodGlobalData
    
    var body: some View {
        let visibleWidth = UIScreen.main.bounds.size.width - UIScreen.main.bounds.size.width / 5
        VStack (alignment: .center, spacing: 0 ) {
            Text("Weght Bearing Protocol")
                .font(.title)
            Text("Max allowed weight (%)")
                .font(.title2)
            //VStack(alignment:.leading, spacing: 10) {
                List {
                    HStack {
                        Text(podData.schedule[0].start)
                            .frame(width: visibleWidth/4, alignment: .leading)
                            .bold()
                        Text(podData.schedule[0].end)
                            .frame(width: visibleWidth/4, alignment: .leading)
                            .bold()
                        Text(podData.schedule[0].front)
                            .frame(width: visibleWidth/4, alignment: .leading)
                            .bold()
                        Text(podData.schedule[0].back)
                            .frame(width: visibleWidth/4, alignment: .leading)
                            .bold()
                    }
                    ForEach(1 ..< 6) { index in
                        HStack {
                            Text(podData.schedule[index].start)
                                .frame(width: visibleWidth/4, alignment: .leading)
                            Text(podData.schedule[index].end)
                                .frame(width: visibleWidth/4, alignment: .leading)
                            Text(podData.schedule[index].front)
                                .frame(width: visibleWidth/4, alignment: .leading)
                            Text(podData.schedule[index].back)
                                .frame(width: visibleWidth/4, alignment: .leading)
                       }
                    }
                  //  VStack(alignment:.center, spacing: 0) {
                    HStack {
                        Text("Tracking complete date  " + podData.endDate)
                            .bold()
                            .frame(width: visibleWidth, alignment: .center)
                    }
                }
            //}
            

        }
        //.padding(20)
    }
}

struct BearingProtocolView_Previews: PreviewProvider {
    static var previews: some View {
        BearingProtocolView()
            .environmentObject(PodGlobalData())
    }
}

