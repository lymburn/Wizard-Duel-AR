//
//  Helpers.swift
//  Wizard Duel AR
//
//  Created by Eugene Lu on 2018-06-25.
//  Copyright © 2018 Eugene Lu. All rights reserved.
//

import SceneKit

func+ (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
}

extension CGFloat {
    var degreesToRadians: CGFloat { return self * .pi / 180 }
    var radiansToDegrees: CGFloat { return self * 180 / .pi }
}
